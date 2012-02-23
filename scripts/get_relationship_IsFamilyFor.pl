use strict;
use Data::Dumper;
use Carp;

#
# This is a SAS Component
#


=head1 get_relationship_IsFamilyFor

Example:

    get_relationship_IsFamilyFor -a < ids > table.with.fields.added

would read in a file of ids and add a column for each field in the relationship.

The standard input should be a tab-separated table (i.e., each line
is a tab-separated set of fields).  Normally, the last field in each
line would contain the id. If some other column contains the id,
use

    -c N

where N is the column (from 1) that contains the id.

This is a pipe command. The input is taken from the standard input, and the
output is to the standard output.

=head2 Command-Line Options

=over 4

=item -c Column

This is used only if the column containing id is not the last.

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
 
my @all_from_fields = ( 'id', 'type', 'family_function' );
my @all_rel_fields = ( 'from_link', 'to_link',  );
my @all_to_fields = ( 'id', 'hypothetical' );

my %all_from_fields = map { $_ => 1 } @all_from_fields;
my %all_rel_fields = map { $_ => 1 } @all_rel_fields;
my %all_to_fields = map { $_ => 1 } @all_to_fields;

my @default_fields = ('from-link', 'to-link');

my @from_fields;
my @rel_fields;
my @to_fields;

my $usage = "usage: get_relationship_IsFamilyFor [-c column] [-a | -from field list -rel field list -to field list] < ids > extended.by.a.column(s)";

my $column;
my $input_file;
my $a;
my $f;
my $r;
my $t;
my $h;
my $i = "-";

my $geO = CDMIClient->new_get_entity_for_script('c=i'	   => \$column,
						"h"	   => \$h,
						"a"	   => \$a,
						"from=s" => \$f,
						"rel=s" => \$r,
						"to=s" => \$t,
						'i=s'	   => \$i);		      

if ($h) {
	print "from: ", join(",", @all_from_fields), "\n";
	print "relation: ", join(",", @all_rel_fields), "\n";
	print "to: ", join(",", @all_to_fields), "\n";
	exit;
}

if ($a  && ($f || $r || $t)) {die $usage};

if ($a) {
	@from_fields = @all_from_fields;
	@rel_fields = @all_rel_fields;
	@to_fields = @all_to_fields;
} elsif ($f || $t || $r) {
	my $err = 0;
	if ($f) {
		@from_fields = split(",", $f);
		$err += check_fields(\@from_fields, %all_from_fields);
	}
	if ($r) {
		@rel_fields = split(",", $r);
		$err += check_fields(\@rel_fields, %all_rel_fields);
	}
	if ($t) {
		@to_fields = split(",", $t);
		$err += check_fields(\@to_fields, %all_to_fields);
	}
	if ($err) {exit 1;}	
} else {
	@rel_fields =  @default_fields;
}
 
my $ih;
if ($input_file)
{
    open $ih, "<", $input_file or die "Cannot open input file $input_file: $!";
}
else
{
    $ih = \*STDIN;
}


my %lines;
while (my @tuples = ScriptThing::GetBatch($ih, undef, $column)) {
    for my $tuple (@tuples) {
	my ($id, $line) = @$tuple;
	$lines{$id} = $line;
    }
	
    my @h = map { $_->[0] } @tuples;
    my $h = $geO->get_relationship_IsFamilyFor(\@h, \@from_fields, \@rel_fields, \@to_fields); 
    for my $result (@$h) {
        my @from;
        my @rel;
        my @to;
        my $from_id;
        my $res = $result->[0];
	for my $key (@from_fields) {
		push (@from,$res->{$key});
	}
        my $res = $result->[1];
	$from_id = $res->{'from_link'};
	for my $key (@rel_fields) {
		push (@rel,$res->{$key});
	}
	my $res = $result->[2];
	for my $key (@to_fields) {
		push (@to,$res->{$key});
	}
        if ($from_id) {
		print join("\t", $lines{$from_id}, @from, @rel, @to), "\n";
        }
    }
}

sub check_fields {
	my ($fields, %all_fields) = @_;
	my @err;
	for my $field (@$fields) {
		if (!$all_fields{$field})
		{
		    push(@err, $field);
		}
        }
	if (@err) {
		my @f = keys %all_fields;
		print STDERR "get_relationship_IsFamilyFor: unknown fields @err. Valid fields are @f\n";
		return 1;
	}
	return 0;
}

