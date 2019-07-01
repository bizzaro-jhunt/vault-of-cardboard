use utf8;
package VCB::DB::Result::Collection;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VCB::DB::Result::Collection

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<collections>

=cut

__PACKAGE__->table("collections");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  is_nullable: 0

=head2 user_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0

=head2 main

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 type

  data_type: 'varchar'
  default_value: 'collection'
  is_nullable: 0
  size: 10

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 notes

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "uuid", is_nullable => 0 },
  "user_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0 },
  "main",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "type",
  {
    data_type => "varchar",
    default_value => "collection",
    is_nullable => 0,
    size => 10,
  },
  "name",
  { data_type => "text", is_nullable => 1 },
  "notes",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<user_id_name_unique>

=over 4

=item * L</user_id>

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id_name_unique", ["user_id", "name"]);

=head1 RELATIONS

=head2 cards

Type: has_many

Related object: L<VCB::DB::Result::Card>

=cut

__PACKAGE__->has_many(
  "cards",
  "VCB::DB::Result::Card",
  { "foreign.collection_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<VCB::DB::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "VCB::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-03-03 14:28:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:q5LBJL00C2MgtlmRiVbuFA

use Data::UUID ();

sub replay {
	my ($self, @changes) = @_;

	# FIXME : transactions!
	$self->cards->delete_all;

	my $UUID = Data::UUID->new;

	for my $change (@changes) {
		printf "ingesting change '%s' [%s], of type '%s'\n", $change->summary, $change->id, $change->type;
		my ($gain, $loss) = $change->cards;
		for (@$loss) {
			$_->quantity *= -1;
		}

		for my $card ((@$gain, @$loss)) {
			my $print = $self->result_source->schema->resultset('Print')->search({
				name   => $card->{name},
				set_id => $card->{set},
			}) or die "card [$card->{set}] '$card->{name}' not found in print table.\n";

			$print->count > 0
				or die "card '$card->{name}' ($card->{set}) not found in print cards table.\n";
			$print->count == 1
				or print STDERR "card '$card->{name}' ($card->{set}) found more than once in print cards table.\n";
			$print = $print->first;

			my $existing = $self->cards->find({
				print_id => $print->id,
				quality  => $card->{quality} || 'U',
				flags    => $card->{flags}    || '',
			});
			if ($existing) {
				my $n = $existing->quantity($existing->quantity + $card->{quantity});
				if ($n <= 0) {
					print "  - removing '$card->{name}' ($card->{set}) from collection...\n";
					$existing->delete;
				} else {
					my $copy = $n == 1 ? "copy" : "copies";
					print "  - collection now has $n $copy of '$card->{name}' ($card->{set})...\n";
					$existing->update;
				}

			} elsif (!$existing) {
				my $n = $card->{quantity};
				my $copy = $n == 1 ? "copy" : "copies";
				print "  - adding $n $copy of '$card->{name}' ($card->{set}) to collection...\n";
				$self->cards->create({
					id       => lc($UUID->to_string($UUID->create)),
					print_id => $print->id,
					proxied  => 0,
					quality  => $card->{quality}  || 'U',
					quantity => $card->{quantity} || 1,
					flags    => $card->{flags}    || '',
				}) or die "failed to put card '$card->{name}' ($card->{set}) into collection.\n";
			}
		}
	}
	return $self;
}

1;
