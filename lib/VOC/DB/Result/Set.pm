use utf8;
package VOC::DB::Result::Set;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VOC::DB::Result::Set

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sets>

=cut

__PACKAGE__->table("sets");

=head1 ACCESSORS

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 6

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 release

  data_type: 'date'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "code",
  { data_type => "varchar", is_nullable => 0, size => 6 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "release",
  { data_type => "date", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->set_primary_key("code");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_unique>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

=head1 RELATIONS

=head2 prints

Type: has_many

Related object: L<VOC::DB::Result::Print>

=cut

__PACKAGE__->has_many(
  "prints",
  "VOC::DB::Result::Print",
  { "foreign.set_id" => "self.code" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-12-12 12:05:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:v9vSSS7k1n5N214ErMhRWA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
