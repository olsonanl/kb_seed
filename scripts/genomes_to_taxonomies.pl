use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#

=head1 genomes_to_taxonomies

Example:

    genomes_to_taxonomies [arguments] < input > output

The standard input should be a tab-separated table (i.e., each line
is a tab-separated set of fields).  Normally, the last field in each
line would contain the identifer. If another column contains the identifier
use

    -c N

where N is the column (from 1) that contains the subsystem.

This is a pipe command. The input is taken from the standard input, and the
output is to the standard output.

=head2 Documentation for underlying call

This script is a wrapper for the CDMI-API call genomes_to_taxonomies. It is documented as follows:

  $return = $obj->genomes_to_taxonomies($genomes)

=over 4

=item Parameter and return types

=begin html

<pre>
$genomes is a genomes
$return is a reference to a hash where the key is a genome and the value is a taxonomic_groups
genomes is a reference to a list where each element is a genome
genome is a string
taxonomic_groups is a reference to a list where each element is a taxonomic_group
taxonomic_group is a string

</pre>

=end html

=begin text

$genomes is a genomes
$return is a reference to a hash where the key is a genome and the value is a taxonomic_groups
genomes is a reference to a list where each element is a genome
genome is a string
taxonomic_groups is a reference to a list where each element is a taxonomic_group
taxonomic_group is a string


=end text

=back

=head2 Command-Line Options

=over 4

=item -c Column

This is used only if the column containing the subsystem is not the last column.

=item -i InputFile    [ use InputFile, rather than stdin ]

=back

=head2 Output Format

The standard output is a tab-delimited file. It consists of the input
file with extra columns added.

Input lines that cannot be extended are written to stderr.

=cut

use SeedUtils;

my $usage = "usage: genomes_to_taxonomies [-c column] < input > output";

use CDMIClient;
use ScriptThing;

my $column;

my $input_file;

my $kbO = CDMIClient->new_for_script('c=i' => \$column,
				      'i=s' => \$input_file);
if (! $kbO) { print STDERR $usage; exit }

my $ih;
if ($input_file)
{
    open $ih, "<", $input_file or die "Cannot open input file $input_file: $!";
}
else
{
    $ih = \*STDIN;
}

while (my @tuples = ScriptThing::GetBatch($ih, undef, $column)) {
    my @h = map { $_->[0] } @tuples;
    my $h = $kbO->genomes_to_taxonomies(\@h);
    for my $tuple (@tuples) {
        #
        # Process output here and print.
        #
        my ($id, $line) = @$tuple;
        my $v = $h->{$id};

        if (! defined($v))
        {
            print STDERR $line,"\n";
        }
        elsif (ref($v) eq 'ARRAY')
        {
		my $a = join(": ", @$v);
                print "$line\t$a\n";
        }
        else
        {
            print "$line\t$v\n";
        }
    }
}
