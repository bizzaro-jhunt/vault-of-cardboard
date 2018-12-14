use utf8;
package VCB::DB::Result::Card;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VCB::DB::Result::Card

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cards>

=cut

__PACKAGE__->table("cards");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  is_nullable: 0

=head2 print_id

  data_type: 'uuid'
  default_value: null
  is_foreign_key: 1
  is_nullable: 1

=head2 proxied

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 flags

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 1

=head2 quantity

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 quality

  data_type: 'varchar'
  default_value: 'G'
  is_nullable: 0
  size: 2

=head2 collection_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "uuid", is_nullable => 0 },
  "print_id",
  {
    data_type      => "uuid",
    default_value  => \"null",
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "proxied",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "flags",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 1 },
  "quantity",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "quality",
  { data_type => "varchar", default_value => "G", is_nullable => 0, size => 2 },
  "collection_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 collection

Type: belongs_to

Related object: L<VCB::DB::Result::Collection>

=cut

__PACKAGE__->belongs_to(
  "collection",
  "VCB::DB::Result::Collection",
  { id => "collection_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 print

Type: belongs_to

Related object: L<VCB::DB::Result::Print>

=cut

__PACKAGE__->belongs_to(
  "print",
  "VCB::DB::Result::Print",
  { id => "print_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-12-13 22:16:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6Yhipdo5eMFp5+flGrNFjw

1;
