use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 all_entities_Environment

Return all instances of the Environment entity.

An Environment is a set of conditions for microbial growth,
including temperature, aerobicity, media, and supplementary
conditions.

Example:

    all_entities_Environment -a 

would retrieve all entities of type Environment and include all fields
in the entities in the output.

=head2 Related entities

The Environment entity has the following relationship links:

=over 4
    
=item HasMedia Media

=item HasParameter Parameter

=item IncludesAdditionalCompounds Compound

=item IsContextOf ExperimentalUnit


=back


=head2 Command-Line Options

=over 4

=item -a

Return all fields.

=item -h

Display a list of the fields available for use.

=item -fields field-list

Choose a set of fields to return. Field-list is a comma-separated list of 
strings. The following fields are available:

=over 4

=item temperature

=item description

=item oxygenConcentration

=item pH

=item source_id

=back    
   
=back

=head2 Output Format

The standard output is a tab-delimited file. It consists of the input
file with an extra column added for each requested field.  Input lines that cannot
be extended are written to stderr.  

=cut

use Bio::KBase::CDMI::CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'temperature', 'description', 'oxygenConcentration', 'pH', 'source_id' );
my %all_fields = map { $_ => 1 } @all_fields;

my $usage = "usage: all_entities_Environment [-show-fields] [-a | -f field list] > entity.data";

my $a;
my $f;
my @fields;
my $show_fields;
my $geO = Bio::KBase::CDMI::CDMIClient->new_get_entity_for_script("a" 		=> \$a,
								  "show-fields" => \$show_fields,
								  "h" 		=> \$show_fields,
								  "fields=s"    => \$f);

if ($show_fields)
{
    print STDERR "Available fields: @all_fields\n";
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
	print STDERR "all_entities_Environment: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
}

my $start = 0;
my $count = 1_000_000;

my $h = $geO->all_entities_Environment($start, $count, \@fields );

while (%$h)
{
    while (my($k, $v) = each %$h)
    {
	print join("\t", $k, map { ref($_) eq 'ARRAY' ? join(",", @$_) : $_ } @$v{@fields}), "\n";
    }
    $start += $count;
    $h = $geO->all_entities_Environment($start, $count, \@fields);
}
