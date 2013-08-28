use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 NAME

er-all-entities-Person

=head1 SYNOPSIS

er-all-entities-Person [-a] [--fields fieldlist] > entity-data

=head1 DESCRIPTION

Return all instances of the Person entity.

A person represents a human affiliated in some way with Kbase.

Example:

    er-all-entities-Person -a 

would retrieve all entities of type Person and include all fields
in the entities in the output.

=head2 Related entities

The Person entity has the following relationship links:

=over 4
    
=item PerformedExperiment ExperimentMeta


=back

=head1 COMMAND-LINE OPTIONS

Usage: er-all-entities-Person [arguments] > entity.data

    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

=over 4    

=item firstName

The given name of the person.

=item lastName

The surname of the person.

=item contactEmail

Email address of the person.

=item institution

The institution where the person works.

=item source_id

The ID of the person used by the data source.


=back

=head1 AUTHORS

L<The SEED Project|http://www.theseed.org>

=cut

use Bio::KBase::CDMI::CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'firstName', 'lastName', 'contactEmail', 'institution', 'source_id' );
my %all_fields = map { $_ => 1 } @all_fields;

our $usage = <<'END';
Usage: er-all-entities-Person [arguments] > entity.data

    --fields list   Choose a set of fields to return. List is a comma-separated list of strings.
    -a		    Return all available fields.
    --show-fields   List the available fields.

The following fields are available:

    firstName
        The given name of the person.
    lastName
        The surname of the person.
    contactEmail
        Email address of the person.
    institution
        The institution where the person works.
    source_id
        The ID of the person used by the data source.
END


my $a;
my $f;
my @fields;
my $show_fields;
my $help;
my $geO = Bio::KBase::CDMI::CDMIClient->new_get_entity_for_script("a" 		=> \$a,
								  "show-fields" => \$show_fields,
								  "h" 		=> \$help,
								  "fields=s"    => \$f);

if ($help)
{
    print $usage;
    exit 0;
}

if ($show_fields)
{
    print "Available fields:\n";
    print "\t$_\n" foreach @all_fields;
    exit 0;
}

if (@ARGV != 0 || ($a && $f))
{
    print STDERR $usage, "\n";
    exit 1;
}

if ($a)
{
    @fields = @all_fields;
}
elsif ($f) {
    my @err;
    for my $field (split(",", $f))
    {
	if (!$all_fields{$field})
	{
	    push(@err, $field);
	}
	else
	{
	    push(@fields, $field);
	}
    }
    if (@err)
    {
	print STDERR "er-all-entities-Person: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
}

my $start = 0;
my $count = 1_000_000;

my $h = $geO->all_entities_Person($start, $count, \@fields );

while (%$h)
{
    while (my($k, $v) = each %$h)
    {
	print join("\t", $k, map { ref($_) eq 'ARRAY' ? join(",", @$_) : $_ } @$v{@fields}), "\n";
    }
    $start += $count;
    $h = $geO->all_entities_Person($start, $count, \@fields);
}
