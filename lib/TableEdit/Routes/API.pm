package TableEdit::Routes::API;

use Dancer ':syntax';
use POSIX;

use Array::Utils qw(:all);
use Digest::SHA qw(sha256_hex);
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Dancer::Plugin::Auth::Extensible;
use FindBin;
use Cwd qw/realpath/;
use YAML::Tiny;
use Scalar::Util 'blessed';
use File::Path qw(make_path remove_tree);

use TableEdit::SchemaInfo;
use TableEdit::Session;

# Global variables
my $appdir = realpath( "$FindBin::Bin/..");
my $menu;
my $schema_info;

prefix '/api';


any '**' => sub {
    # load schema if necessary
    $schema_info ||= TableEdit::SchemaInfo->new(
        schema => schema,
        sort => 1,
	);
	TableEdit::Session::seen();
    
    debug "Route: ", request->uri;

	content_type 'application/json';
	pass;
};


get '/:class/:id/:related/list' => require_login sub {
	my $id = param('id');
	my $class_info = $schema_info->class(param('class'));
	my $related = param('related');
	my $data;

	# Row lookup
	my $row = $class_info->resultset->find($id);
	my $rowInfo = $schema_info->row($row);
	
	# Related list
	my $relationship_info = $class_info->relationship($related);
	my $related_items = $row->$related;
	
	return '{}' unless ( defined $row );	
	$data->{'id'} = $id;
	$data->{'class'} = $class_info->name;
	$data->{'related_class'} = $relationship_info->class_name;
	$data->{'related_class_label'} = $relationship_info->label;
	$data->{'related_type'} = $relationship_info->type;
	$data->{'title'} = $rowInfo->to_string;
	
	return to_json $data;
};


post '/:class/:id/:related/:related_id' => require_login sub {
	my $id = param('id');
	my $class_info = $schema_info->class(param('class'));
	my $related = param('related');
	my $related_id = param('related_id');
	
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = $schema_info->class($relationship_info->class_name);
	my $related_row = $relationship_class_info->resultset->find($related_id);
	
	my $row = $class_info->resultset->find($id);
	
	# Has many
	if($relationship_info->cond){
		my $column_name;
		for my $cond (keys %{$relationship_info->cond}){
			$column_name = [split('\.', "$cond")]->[-1];
			last;
		}		
		$related_row->$column_name($id);
		$related_row->update;
	}
	# Many to Many
	else {
		my $add_method = "add_to_$related"; 
		$row->$add_method($related_row);	
	}
	return 1;
};


del '/:class/:id/:related/:related_id' => require_login sub {
	my $id = param('id');
	my $class_info = $schema_info->class(param('class'));
	my $related = param('related');
	my $related_id = param('related_id');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = $schema_info->class($relationship_info->class_name);
	
	my $row = $class_info->resultset->find($id);
	my $related_row = $relationship_class_info->resultset->find($related_id);
	
	# Has many
	if($relationship_info->{cond}){ 
		my $column_name;
		for my $cond (keys %{$relationship_info->{cond}}){
			$column_name = [split('\.', "$cond")]->[-1];
			last;
		}		
		$related_row->$column_name(undef);
		$related_row->update;
	}
	# Many to Many
	else {
		my $add_method = "remove_from_$related"; 
		$row->$add_method($related_row);	
	}

	return 1;
};


get '/:class/:id/:related/items' => require_login sub {
	my $id = param('id');
	my $class_info = $schema_info->class(param('class'));
	my $related = param('related');
	my ($row, $data);
	my $get_params = params('query') || {};

	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = $schema_info->class($relationship_info->class_name);

	# row lookup
	$row = $class_info->resultset->find($id);
	my $related_items = $row->$related;
	
	# Related bind
	$data = grid_template_params($relationship_class_info, $related_items);
	
	return to_json( $data, {allow_unknown => 1} );
};


get '/:class/:related/list' => require_login sub {
	my $class_info = $schema_info->class(param('class'));
	my $related = param('related');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class = $relationship_info->class_name;
	return forward "/api/$relationship_class/list"; 	
};


# Class listing
get '/:class/list' => require_login sub {
	my $class_info = $schema_info->class(param('class'));
	my $grid_params = grid_template_params($class_info);
	
	return to_json($grid_params, {allow_unknown => 1});
};


get '/menu' => sub {
    if (! $menu) {
        $menu = [
        	map {{name => $_->label, url=> join('/', '#' . $_->name, 'list'),}}	$schema_info->classes,
	    ]
    }
    return to_json $menu;
};


post '/:class/:column/upload_image' => require_login sub {
	my $class = param('class');
	my $class_info = $schema_info->class($class);
	my $column = param('column');
	my $column_info = $class_info->column($column);
	my $file = upload('file');
	
	# Upload dir
	my $path = $column_info->upload_dir; 
	
	# Upload image
    if($file){
		my $fileName = $file->{filename};
		
		my $dir = "$appdir/public/$path";
		make_path $dir unless (-e $dir);       
		
		if($file->copy_to($dir.$fileName)){			
			return "/$path$fileName";
		}		
    }
	return undef;
};


get '/:class/:id' => require_login sub {
	my ($data);
	my $id = param('id');
	my $class_info = $schema_info->class(param('class'));

	$data->{columns} = $class_info->columns_info;

	# row lookup
	my $row = $class_info->resultset->find($id);
	return status '404' unless $row;
	 
	my $rowInfo = $schema_info->row($row);
	$data->{title} = $rowInfo->to_string;
	$data->{id} = $id;
	$data->{class} = $class_info->name;
	$data->{values} = {$row->get_columns};
	return to_json($data, {allow_unknown => 1});
};


get '/:class' => require_login sub {
	my $class_info = $schema_info->class(param('class'));

	return to_json({ 
		columns => $class_info->form_columns_info,
		class => $class_info->name,
		class_label => $class_info->label,
		relations => $class_info->relationships_info,
	}, {allow_unknown => 1}); 
};


post '/:class' => require_login sub {
	my $class_info = $schema_info->class(param('class'));
	my $body = from_json request->body;
	my $item = $body->{item};

	debug "Updating item for ".$class_info->name.": ", $item;
	
	return $class_info->resultset->update_or_create( $item->{values} );
};


del '/:class' => require_login sub {
	my $id = param('id');
	my $class_info = $schema_info->class(param('class'));
	my $row = $class_info->resultset->find($id);

    return status '404' unless $row;

	$row->delete;
	return 1;
};

=head1 Fuctions

=head2 add_values

Adds values to column objects

=cut

sub add_values {
	my ($columns_info, $values) = @_;
	for my $column_info (@$columns_info){
		$column_info->{value} =  $values->{$column_info->{name}}
	}
}


=head2 grid_template_params

Returns data for grid view

=cut

sub grid_template_params {
	my ($class_info, $related_items) = @_;
	my $get_params = params('query');
	my $grid_params;
	my $where = {};	
	# Grid
	$grid_params->{column_list} = $class_info->grid_columns_info; 
	my $where_params = from_json $get_params->{q} if $get_params->{q};
	grid_where($grid_params->{column_list}, $where, $where_params);
	add_values($grid_params->{column_list}, $where_params);
	
	my $rs = $related_items || $class_info->resultset;

	my $primary_column = $class_info->primary_key;
    
	my $page = $get_params->{page} || 1;
	my $page_size = $get_params->{page_size} || config->{TableEditor}->{page_size};
	
	my $rows = $rs->search(
	$where,
	  {
	    page => $page,  # page to return (defaults to 1)
	    rows => $page_size, # number of results per page
	    order_by => grid_sort($class_info, $get_params),	
	  },);
	my $count = $rs->search($where)->count;

	$grid_params->{rows} = grid_rows(
		[$rows->all], 
		$grid_params->{column_list} , 
		$primary_column, 
	);
	
	$class_info->label;
	$class_info->label;
	
	$grid_params->{class} = $class_info->name;
	$grid_params->{class_label} = $class_info->label;
	$grid_params->{page} = $page;
	$grid_params->{pages} = ceil($count / $page_size);
	$grid_params->{count} = $count;
	$grid_params->{page_size} = $page_size;
	
	return $grid_params;
}


=head2 grid_sort

Returns sql order by parameter.

=cut

sub grid_sort {
	my ($class_info, $get_params) = @_;
	# Selected or Predefined sort
	my $sort = $get_params->{sort} || $class_info->attr('grid_sort');
	# Direction	
	$sort .= $get_params->{descending} ? ' DESC' : '' if $sort;
	return $sort;
}


=head2 grid_where

Sets sql conditions.

=cut

sub grid_where {
	my ($columns, $where, $params, $alias) = @_;
	$alias ||= 'me';
	for my $column (@$columns) {
		# Search
		my $name = $column->{name};
		if( defined $params->{$name} and $params->{$name} ne '' ){
			if ($column->{data_type} and ($column->{data_type} eq 'text' or $column->{data_type} eq 'varchar')){
				$where->{"LOWER($alias.$name)"} = {'LIKE' => "%".lc($params->{$name})."%"};
			}
			else { 
				$where->{"$alias.$name"} = $params->{$name};	
			}
		}
	};
	
}

=head2 grid_rows

Returns a list of database records suitable for the grid display.

=cut

sub grid_rows {
	my ($rows, $columns_info, $primary_column, $args) = @_;

	my @table_rows;

	for my $row (@$rows){
		die 'No primary column' unless $primary_column;
		my $rowInfo = $schema_info->row($row);
		
		# unravel row
		my $row_inflated = {$row->get_inflated_columns};
		my $id = $row->$primary_column;
		my $row_data = [];

		for my $column (@$columns_info){
			
			my $column_name = $column->{foreign} ? "$column->{foreign}" : "$column->{name}";
			my $value = $row_inflated->{$column_name};
			push @$row_data, {value => $value};
		}

		push @table_rows, {
            row => $row_data,
            id => $id,
            name => $rowInfo->to_string,
            columns => $row_inflated,
        };
	}

	return \@table_rows;
}


true;
