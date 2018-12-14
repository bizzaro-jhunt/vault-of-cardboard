use utf8;
package VCB::DB::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VCB::DB::Result::User

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  is_nullable: 0

=head2 account

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 pwhash

  data_type: 'text'
  is_nullable: 1

=head2 display

  data_type: 'text'
  is_nullable: 1

=head2 joined_at

  data_type: 'integer'
  is_nullable: 0

=head2 admin

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 active

  data_type: 'boolean'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "uuid", is_nullable => 0 },
  "account",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "pwhash",
  { data_type => "text", is_nullable => 1 },
  "display",
  { data_type => "text", is_nullable => 1 },
  "joined_at",
  { data_type => "integer", is_nullable => 0 },
  "admin",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "active",
  { data_type => "boolean", default_value => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<account_unique>

=over 4

=item * L</account>

=back

=cut

__PACKAGE__->add_unique_constraint("account_unique", ["account"]);

=head1 RELATIONS

=head2 collections

Type: has_many

Related object: L<VCB::DB::Result::Collection>

=cut

__PACKAGE__->has_many(
  "collections",
  "VCB::DB::Result::Collection",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-12-13 22:16:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5Mpkvny2qysi1EyzOaKm+Q

use Data::Entropy::Algorithms qw/rand_bits/;
use Digest                    qw//;

sub set_password {
	my ($self, $password) = @_;

	my $bc = Digest->new(
		'Bcrypt',
		cost => $ENV{VCB_DIGEST_BCRYPT_COST} || 12, # in range (0,31)
		salt => rand_bits(16*8),                    # 16 octets
	);

	$bc->add($password);
	$self->pwhash($bc->settings.'$'.$bc->hexdigest);
	return $self;
}

sub authenticate {
	my ($self, $password) = @_;

	# extract settings from the password hash stored in the database
	# (this way we get back the salt and cost information originally used)
	#
	return undef unless $self->pwhash =~ m/^(.*)\$(.*?)$/;
	my ($settings, $hash) = ($1, $2);

	# check the stored pwhash against calculated pwhash.
	return $hash eq Digest->new('Bcrypt', settings => $settings)->add($password)->hexdigest;
}

sub primary_collection {
	my ($self) = @_;
	$self->collections->search({ main => 1, type => 'collection' })->first;
}

1;
