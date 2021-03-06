package TableEdit::RowInfo;

use DBI;
use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

with 'TableEdit::SchemaInfo::Role::Config';

=head1 NAME

TableEdit::RowInfo - Extended DBIx::Class::Row 

=head1 ATTRIBUTES

=cut

has row => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['DBIx::Class::Row'],
);


=head2 class

Returns L<TableEdit::ClassInfo> object that tow belongs.

=cut

has class => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['TableEdit::ClassInfo'],
);



=head2 label

String representation of object

=cut
use overload
'""' => 'to_string';       

sub to_string {
	my $self = shift;

	# Config set label
	my $row = $self->row;
	my $label = eval $self->attr('to_string') if $self->attr('to_string');
	return $label if $label;

	# Try common names
	my @common_names = qw/title name label username/;
	for my $name (@common_names){
		return $self->row->$name if $self->row->can($name);
	}

	# Generate generic unique name
	my $class = $self->row->result_source->{source_name};
	my $primary_key = $self->class->primary_key;
	my $id = $self->primary_key_string;
	return "$id - ".$self->class->label;
}


=head2 attributes

=cut
sub attr  {
		my ($self, @path) = @_;
		my $value;
		my $node = $self->class->config->{classes}->{$self->class->name};
		for my $p (@path){
			$node = $node->{$p};
			return $node unless defined $node;
		}
		return $node;
}

sub primary_key_value {
	my $self = shift;
	my $primary_key = $self->class->primary_key;
	my $primary_key_value;
	for my $key (@$primary_key){
		$primary_key_value->{$key} = $self->row->$key;
	}
	return $primary_key_value;
}

sub primary_key_string {
	my $self = shift;
	my $delimiter = $self->class->schema->primary_key_delimiter;
	my $primary_key = $self->class->primary_key;
	my @primary_key_value;
	for my $key (@$primary_key){
		push @primary_key_value, $self->row->$key;
	}
	return join($delimiter, @primary_key_value);
}

sub string_values {
	my $self = shift;
	my $values = {$self->row->get_columns};
	return {map {$_ => defined $values->{$_} ? $values->{$_}."" : ""} keys %$values}
}

1;
