use utf8;
package VCB::DB::Result::Change;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VCB::DB::Result::Change

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<changes>

=cut

__PACKAGE__->table("changes");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  is_nullable: 0

=head2 user_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 occurred_at

  data_type: 'integer'
  is_nullable: 0

=head2 summary

  data_type: 'text'
  is_nullable: 0

=head2 notes

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 raw_gain

  data_type: 'text'
  is_nullable: 1

=head2 card_gain

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 unique_gain

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 raw_loss

  data_type: 'text'
  is_nullable: 1

=head2 card_loss

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 unique_loss

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 sets

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 analyzed

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "uuid", is_nullable => 0 },
  "user_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "occurred_at",
  { data_type => "integer", is_nullable => 0 },
  "summary",
  { data_type => "text", is_nullable => 0 },
  "notes",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "raw_gain",
  { data_type => "text", is_nullable => 1 },
  "card_gain",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "unique_gain",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "raw_loss",
  { data_type => "text", is_nullable => 1 },
  "card_loss",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "unique_loss",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "sets",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "analyzed",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-03-03 16:57:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6GsYnDlQB6Yr0V7LXfdeEg

use VCB::Format;

sub cards {
	my ($self) = @_;
	return
		VCB::Format->parse($self->raw_gain);
		VCB::Format->parse($self->raw_loss);
}

1;
