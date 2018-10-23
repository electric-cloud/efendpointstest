#!/usr/bin/env ec-perl
#
use ElectricCommander;
use HTTP::Daemon;
use JSON;
use Data::Dumper;

$SIG{CHLD} = 'IGNORE';

my $d = HTTP::Daemon->new(LocalPort => 8888) || die;
print "Please contact me at: <URL:", $d->url, ">\n";


while (my $c = $d->accept) {
    unless (fork()) {
        my $username = $ENV{MOCKFLOW_USER} ||= 'admin';
        my $password = $ENV{MOCKFLOW_PASS} ||= 'changeme';
        my $host = $ENV{MOCKFLOW_EF_HOST} ||= 'localhost';
        my $ec = new ElectricCommander({server => $host});
        $ec->login($username, $password);
        print "Logged in successfully\n";

        while (my $r = $c->get_request) {
            if ($r->uri->path eq "/test" or $r->method eq 'POST' and $r->uri->path eq "/endpoints/EC-Github/1.0/webhook") {
                my $jobId = eval {
                    my $prop = $ec->getProperty("/myPlugin/project/ec_endpoints/webhook/dsl", {pluginName => "EC-Github"});
                    my $dsl = $prop->findvalue("//value")->value();
                    my $response = $ec->evalDsl($dsl);
                    $response->findvalue("//jobId")->value();
                };
                if ($@) {
                    $c->send_status_line(500);
                    $c->send_header( "Content-type", "text/plain" );
                    printf $c "\nEncountered error:\n%s\n", $@;
                } else {
                    printf STDERR "JobID: %s\n", $jobId;
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

