#!/usr/bin/env ec-perl
#
use ElectricCommander;
use HTTP::Daemon;
use JSON;
use Data::Dumper;

sub TO_JSON { return { %{ shift() } }; }

$SIG{CHLD} = 'IGNORE';

my $d = HTTP::Daemon->new(LocalPort => 8888) || die;
print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    unless (fork()) {
        my $ec = new ElectricCommander();
        $ec->login('admin','changeme');

        while (my $r = $c->get_request) {
            if ($r->uri->path eq "/test" or $r->method eq 'POST' and $r->uri->path eq "/endpoints/EC-Github/1.0/webhook") {
                my $jobId = eval {
                    my $prop = $ec->getProperty("/myPlugin/project/ec_endpoints/webhook/dsl", {pluginName => "EC-Github"});
                    my $dsl = $prop->findvalue("//value")->value();
					
					my $headers = "" . encode_json TO_JSON ($r->headers); # Force JSON to string
					my $payload = "" . $r->content;
					print STDERR "\n" . "Payload: " . $payload;
					print STDERR "\n" . "Headers: " . $headers;

					my $response = $ec->evalDsl(
						$dsl, {
							parameters => qq(
								{
									"headers": $headers,
									"payload": $payload
								}
							)
						},
					);
				
                    $response->findvalue("//jobId")->value();
                };
                if ($@) {
                    $c->send_status_line(500);
                    $c->send_header( "Content-type", "text/plain" );
                    printf $c "\nEncountered error:\n%s\n", $@;
                } else {
                    printf STDERR "\nJobID: %s\n", $jobId;
                    $c->send_status_line;
                    $c->send_header( "Content-type", "text/plain" );
                    printf $c "\nJobID: %s\n", $jobId;
                }
            } else {
                $c->send_status_line(404);
                $c->send_header( "Content-type", "text/plain" );
                print $c "\nUnknown call\n\n";
            }
            $c->close;
            undef($c);
            exit;
        }
    }
}

