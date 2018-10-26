#!/usr/bin/env ec-perl
#
use ElectricCommander;
use HTTP::Daemon;
use JSON;
use Data::Dumper;

sub TO_JSON { return { %{ shift() } }; }

$SIG{CHLD} = 'IGNORE';

my $user = $ENV{MOCKFLOW_USER} ||= 'admin';
my $password = $ENV{MOCKFLOW_PASS} ||= 'changeme';
my $host = $ENV{MOCKFLOW_EF_HOST} ||= 'localhost';

my $d = HTTP::Daemon->new(LocalPort => 8888) || die;
print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    unless (fork()) {
        my $ec = new ElectricCommander({server => $host});
        $ec->login($user, $password);

        while (my $r = $c->get_request) {
            if ($r->uri->path eq "/test" or $r->method eq 'POST' and $r->uri->path eq "/endpoints/EC-Github/1.0/webhook") {
                my $response = eval {
                    my $prop = $ec->getProperty("/myPlugin/project/ec_endpoints/webhook/dsl", {pluginName => "EC-Github"});
                    my $dsl = $prop->findvalue("//value")->value();

					my $headers = "" . encode_json TO_JSON ($r->headers); # Force JSON to string
					my $payload = "" . $r->content;
					print STDERR "\n" . "Payload: " . $payload;
					print STDERR "\n" . "Headers: " . $headers;
                    print STDERR "\n DSL: $dsl\n";

					my $xpath = $ec->evalDsl(
						$dsl, {
							parameters => qq(
								{
									"headers": $headers,
									"payload": $payload
								}
							)
						},
					);

                    my $value = $xpath->findvalue("//value")->value();
                    print STDERR $value;
                    decode_json($value);
                };
                if ($@) {
                    $c->send_status_line(500);
                    $c->send_header( "Content-type", "text/plain" );
                    printf $c "\nEncountered error:\n%s\n", $@;
                } else {
                    printf STDERR "\nResponse: %s\n", Dumper $response;
                    $c->send_status_line;
                    my $content_type = $response->{contentType} ||= 'text/plain';
                    my $body = $response->{body} ||= '';
                    $c->send_header( "Content-type", $content_type );
                    printf $c "\n%s\n", $body;
                    # printf $c "\nJobID: %s\n", $jobId;
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

