use utf8;
package VCB::DB::Result::SchemaVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VCB::DB::Result::SchemaVersion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<schema_version>

=cut

__PACKAGE__->table("schema_version");

=head1 ACCESSORS

=head2 version

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "version",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-01-09 19:35:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E/Z5cQzCFSul3NIo8O1i7g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
