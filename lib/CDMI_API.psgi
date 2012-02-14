use CDMI_APIImpl;
use CDMI_EntityAPIImpl;

use CDMI_APIServer;



my @dispatch;

{
    my $obj = CDMI_APIImpl->new;
    push(@dispatch, 'CDMI_API' => $obj);
}
{
    my $obj = CDMI_EntityAPIImpl->new;
    push(@dispatch, 'CDMI_EntityAPI' => $obj);
}


my $server = CDMI_APIServer->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler;