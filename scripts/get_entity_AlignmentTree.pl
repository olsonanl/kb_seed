use strict;
use Data::Dumper;
use Bio::KBase::Utilities::ScriptThing;
use Carp;

#
# This is a SAS Component
#


=head1 get_entity_AlignmentTree

An alignment arranges a group of protein sequences so that they
match. Each alignment is associated with a phylogenetic tree that
describes how the sequences developed and their evolutionary distance.
The actual tree and alignment FASTA are stored in separate flat files.
The Kbase will maintain a set of alignments and associated
trees.  The majority
of these will be based on protein sequences.  We will not have a comprehensive set
but we will have tens of thousands of such alignments, and we view them as an
imporant resource to support annotation.
The alignments/trees will include the tools and parameters used to construct
them.
Access to the underlying sequences and trees in a form convenient to existing
tools will be supported.


Example:

    get_entity_AlignmentTree -a < ids > table.with.fields.added

would read in a file of ids and add a column for each filed in the entity.

The standard input should be a tab-separated table (i.e., each line
is a tab-separated set of fields).  Normally, the last field in each
line would contain the id. If some other column contains the id,
use

    -c N

where N is the column (from 1) that contains the id.

This is a pipe command. The input is taken from the standard input, and the
output is to the standard output.

=head2 Related entities

The AlignmentTree entity has the following relationship links:

=over 4
    
=item Aligns ProteinSequence


=back

=head2 Command-Line Options

=over 4

=item -c Column

Use the specified column to define the id of the entity to retrieve.

=item -h

Display a list of the fields available for use.

=item -fields field-list

Choose a set of fields to return. Field-list is a comma-separated list of 
strings. The following fields are available:

=over 4

=item alignment_method

=item alignment_parameters

=item alignment_properties

=item tree_method

=item tree_parameters

=item tree_properties

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

my @all_fields = ( 'alignment_method', 'alignment_parameters', 'alignment_properties', 'tree_method', 'tree_parameters', 'tree_properties' );
my %all_fields = map { $_ => 1 } @all_fields;

my $usage = "usage: get_entity_AlignmentTree [-h] [-c column] [-a | -f field list] < ids > extended.by.a.column(s)";

my $column;
my $a;
my $f;
my $i = "-";
my @fields;
my $show_fields;
my $geO = Bio::KBase::CDMI::CDMIClient->new_get_entity_for_script('c=i'	   	=> \$column,
								  "a"	   	=> \$a,
								  "h"	   	=> \$show_fields,
								  "show-fields"	=> \$show_fields,
								  "fields=s" 	=> \$f,
								  'i=s'	   	=> \$i);
if ($show_fields)
{
    print STDERR "Available fields: @all_fields\n";
    exit 0;
}
if ($a && $f) { print STDERR $usage; exit 1 }
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
	print STDERR "get_entity_AlignmentTree: unknown fields @err. Valid fields are: @all_fields\n";
	exit 1;
    }
} else {
    print STDERR $usage;
    exit 1;
}

my $ih;
if ($i eq '-')
{
    $ih = \*STDIN;
}
else
{
    open($ih, "<", $i) or die "Cannot open input file $i: $!\n";
}

while (my @tuples = Bio::KBase::Utilities::ScriptThing::GetBatch($ih, undef, $column)) {
    my @h = map { $_->[0] } @tuples;
    my $h = $geO->get_entity_AlignmentTree(\@h, \@fields);
    for my $tuple (@tuples) {
        my @values;
        my ($id, $line) = @$tuple;
        my $v = $h->{$id};
	if (! defined($v))
	{
	    #nothing found for this id
	    print STDERR $line,"\n";
     	} else {
	    foreach $_ (@fields) {
		my $val = $v->{$_};
		push (@values, ref($val) eq 'ARRAY' ? join(",", @$val) : $val);
	    }
	    my $tail = join("\t", @values);
	    print "$line\t$tail\n";
        }
    }
}
