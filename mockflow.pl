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
print "HOST is $host\n";
my $ec = new ElectricCommander({server => $host});
$ec->login($user, $password);

my $d = HTTP::Daemon->new(LocalPort => 8888) || die;
print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    unless (fork()) {

        while (my $r = $c->get_request) {

            print STDERR Dumper $r;
            my $response = eval {
                processPayload($r);
            };

            logger($@);

            if ($@) {
                $c->send_status_line(500);
                print $c "\nServer Error: $@";
            }
            else {
                my $code = $response->{code} ||= 200;
                $c->send_status_line($code);
                my $headers = $response->{headers};
                for my $header (keys %$headers) {
                    $c->send_header($header, $headers->{$header});
                }

                print $c "\n" . $response->{payload};
            }



                 #            $c->send_status_line(404);
     #            $c->send_header( "Content-type", "text/plain" );
     #            print $c "\nUnknown call\n\n";



     #        if ($r->uri->path eq "/test" or $r->method eq 'POST' and $r->uri->path eq "/endpoints/EC-Github/1.0/webhook") {
     #            my $response = eval {
     #                my $prop = $ec->getProperty("/myPlugin/project/ec_endpoints/webhook/dsl", {pluginName => "EC-Github"});
     #                my $dsl = $prop->findvalue("//value")->value();

					# my $headers = "" . encode_json TO_JSON ($r->headers); # Force JSON to string
					# my $payload = "" . $r->content;
					# print STDERR "\n" . "Payload: " . $payload;
					# print STDERR "\n" . "Headers: " . $headers;
     #                print STDERR "\n DSL: $dsl\n";

					# my $xpath = $ec->evalDsl(
					# 	$dsl, {
					# 		parameters => qq(
					# 			{
					# 				"headers": $headers,
					# 				"payload": $payload
					# 			}
					# 		)
					# 	},
					# );

     #                my $value = $xpath->findvalue("//value")->value();
     #                print STDERR $value;
     #                decode_json($value);
     #            };
     #            if ($@) {
     #                $c->send_status_line(500);
     #                $c->send_header( "Content-type", "text/plain" );
     #                printf $c "\nEncountered error:\n%s\n", $@;
     #            } else {
     #                printf STDERR "\nResponse: %s\n", Dumper $response;
     #                $c->send_status_line;
     #                my $content_type = $response->{contentType} ||= 'text/plain';
     #                my $body = $response->{body} ||= '';
     #                $c->send_header( "Content-type", $content_type );
     #                printf $c "\n%s\n", $body;
     #                # printf $c "\nJobID: %s\n", $jobId;
     #            }
     #        } else {
     #            $c->send_status_line(404);
     #            $c->send_header( "Content-type", "text/plain" );
     #            print $c "\nUnknown call\n\n";
     #        }
            $c->close;
            undef($c);
            exit;
        }
    }
}


sub logger {
    my @messages = @_;
    for my $m (@messages) {
        print STDERR $m . "\n";
    }
}

sub processPayload {
    my ($request) = @_;

    my $uri = $request->uri;
    my $payload = $request->content;
    my $headers = $request->headers;

    my %query = $uri->query_form;

    my $operationId = $query{operationId};
    unless($operationId) {
        die "No operationId found in the query";
    }

    my $pluginKey = $ec->getProperty('/server/ec_endpoints/' . $operationId)->findvalue('//value');
    logger($pluginKey);

    unless($pluginKey) {
        die "No plugin key found in the /server/ec_endpoints";
    }
    my $method = $request->method;
    my $dsl = $ec->getProperty("/plugins/$pluginKey/project/ec_endpoints/$operationId/$method/script")->findvalue('//value');

    my $timeout = eval { $ec->getProperty("/plugins/$pluginKey/project/ec_endpoints/$operationId/$method/timeout")->findvalue('//value') } || 30;
    my $libs = eval { $ec->getProperty("/plugins/$pluginKey/project/ec_endpoints/$operationId/$method/libsPath")->findvalue('//value') } || undef;
    # serverLibraryPath

    my $config = loadConfig($uri, $pluginKey, $operationId, $method);

    my $parameters = {
        method => $method,
        url => "$uri",
        payload => $payload,
        config => $config,
    };

    my $xpath = $ec->evalDsl({
        dsl => $dsl,
        parameters => encode_json($parameters),
        timeout => $timeout * 1000,
        serverLibraryPath => $libs
    });

    logger($xpath->{_xml});

    my $json = $xpath->findvalue('//value') . '';
    logger($json);
    my $response = decode_json($json);
    return $response;

}

sub loadConfig {
    my ($uri, $pluginKey, $operationId, $method) = @_;

    my %query = $uri->query_form;
    my $configname = $query{configname};
    logger("Cofnigname $configname");
    return unless $configname;

    my $pluginKey2;
    eval {
        $pluginKey2 = $ec->getProperty("/plugins/$pluginKey/project/ec_endpoints/$operationId/$method/configurationMetadata/pluginKey")->findvalue('//value')
    };
    $pluginKey2 ||= $pluginKey;

    logger("Pluginkey2 $pluginKey2");
    my $configPath = eval {
        $ec->getProperty("/plugins/$pluginKey/project/ec_endpoints/$operationId/$method/configurationMetadata/configurationPath")->findvalue('//value')
    } || 'ec_plugin_cfgs';
    logger($configPath);

    my $configProperties = $ec->getProperties({path => "/plugins/$pluginKey2/project/$configPath"});

    my $config = {};

    for my $prop ($configProperties->findnodes('//property')) {
        my $name = $prop->findvalue('propertyName');
        my $value = $prop->findvalue('value');
        $config->{$name} = "$value";
    }

    my $creds = $ec->getCredentials({projectName => "/plugins/$pluginKey2/project"});
    for my $cred ($creds->findnodes('//credential')) {
        my $credName = $cred->findvalue('credentialName');
        push @{$config->{credentials}}, {credentialName => "$credName", userName => 'username', password => 'password'}
    }
    return $config;
}
