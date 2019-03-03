use utf8;
package VCB::DB::Result::Print;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VCB::DB::Result::Print

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<prints>

=cut

__PACKAGE__->table("prints");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 type

  data_type: 'text'
  is_nullable: 1

=head2 oracle

  data_type: 'text'
  is_nullable: 1

=head2 flavor

  data_type: 'text'
  is_nullable: 1

=head2 set_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 6

=head2 colnum

  data_type: 'text'
  default_value: null
  is_nullable: 1

=head2 rarity

  data_type: 'varchar'
  is_nullable: 1
  size: 1

=head2 reprint

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 reserved

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 color

  data_type: 'varchar'
  is_nullable: 1
  size: 6

=head2 mana

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 20

=head2 cmc

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 artist

  data_type: 'text'
  is_nullable: 1

=head2 price

  data_type: 'decimal'
  default_value: 0
  is_nullable: 0

=head2 power

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 toughness

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 layout

  data_type: 'text'
  default_value: 'normal'
  is_nullable: 0

=head2 legalese

  data_type: 'text'
  default_value: '{}'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "uuid", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "type",
  { data_type => "text", is_nullable => 1 },
  "oracle",
  { data_type => "text", is_nullable => 1 },
  "flavor",
  { data_type => "text", is_nullable => 1 },
  "set_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 6 },
  "colnum",
  { data_type => "text", default_value => \"null", is_nullable => 1 },
  "rarity",
  { data_type => "varchar", is_nullable => 1, size => 1 },
  "reprint",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "reserved",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "color",
  { data_type => "varchar", is_nullable => 1, size => 6 },
  "mana",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 20 },
  "cmc",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "artist",
  { data_type => "text", is_nullable => 1 },
  "price",
  { data_type => "decimal", default_value => 0, is_nullable => 0 },
  "power",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "toughness",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "layout",
  { data_type => "text", default_value => "normal", is_nullable => 0 },
  "legalese",
  { data_type => "text", default_value => "{}", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 cards

Type: has_many

Related object: L<VCB::DB::Result::Card>

=cut

__PACKAGE__->has_many(
  "cards",
  "VCB::DB::Result::Card",
  { "foreign.print_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 set

Type: belongs_to

Related object: L<VCB::DB::Result::Set>

=cut

__PACKAGE__->belongs_to(
  "set",
  "VCB::DB::Result::Set",
  { code => "set_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-03-02 23:24:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KLDKIsCpwG2xNGgV7aF1+Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
