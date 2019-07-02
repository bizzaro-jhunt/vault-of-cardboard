use utf8;
package VCB::DB::Result::Deck;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VCB::DB::Result::Deck

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<decks>

=cut

__PACKAGE__->table("decks");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  is_nullable: 0

=head2 user_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0

=head2 created_at

  data_type: 'integer'
  is_nullable: 0

=head2 updated_at

  data_type: 'integer'
  is_nullable: 0

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 notes

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 cover

  data_type: 'uuid'
  default_value: null
  is_nullable: 1

=head2 cardlist

  data_type: 'text'
  is_nullable: 1

=head2 format

  data_type: 'varchar'
  default_value: 'custom'
  is_nullable: 0
  size: 30

=head2 colors

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
  "created_at",
  { data_type => "integer", is_nullable => 0 },
  "updated_at",
  { data_type => "integer", is_nullable => 0 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "notes",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "cover",
  { data_type => "uuid", default_value => \"null", is_nullable => 1 },
  "cardlist",
  { data_type => "text", is_nullable => 1 },
  "format",
  {
    data_type => "varchar",
    default_value => "custom",
    is_nullable => 0,
    size => 30,
  },
  "colors",
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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-06-30 15:02:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JVyGovbzC3/3zFCiLkfzVg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
