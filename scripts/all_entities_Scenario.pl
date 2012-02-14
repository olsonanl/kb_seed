use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 all_entities_Scenario

Example:

    all_entities_Scenario -a 

would retrieve all entities of type Scenario and include all fields
in the entities in the output.


=head2 Command-Line Options

=over 4

=item -a

Return all fields.

=back

=head2 Output Format

The standard output is a tab-delimited file. It consists of the input
file with an extra column added for each requested field.  Input lines that cannot
be extended are written to stderr.  

=cut
use ScriptThing;
use CDMIClient;
use Getopt::Long;

#Default fields

my @all_fields = ( 'common_name' );
my %all_fields = map { $_ => 1 } @all_fields;

my $usage = "usage: all_entities_Scenario [-show-fields] [-a | -f field list] > entity.data";

my $a;
my $f;
my @fields;
my $show_fields;
my $geO = CDMIClient->new_get_entity_for_script("a"	      => \$a,
						"show-fields" => \$show_fields,
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
	print STDERR "all_entities_Scenario: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
}

my $start = 0;
my $count = 1000;

my $h = $geO->all_entities_Scenario($start, $count, \@fields );

while (%$h)
{
    while (my($k, $v) = each %$h)
    {
	print join("\t", $k, @$v{@fields}), "\n";
    }
    $start += $count;
    $h = $geO->all_entities_Scenario($start, $count, \@fields);
}
