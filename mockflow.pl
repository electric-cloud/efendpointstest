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
        my $ec = new ElectricCommander();
        $ec->login('admin','changeme');

        while (my $r = $c->get_request) {
            if ($r->uri->path eq "/test" or $r->method eq 'POST' and $r->uri->path eq "/endpoints/EC-Github/1.0/webhook") {
                my $prop = $ec->getProperty("/myPlugin/project/ec_endpoints/webhook/dsl", {pluginName => "EC-Github"});
                my $dsl = $prop->findvalue("//value")->value();
                my $response = $ec->evalDsl($dsl);
                my $jobId = $response->findvalue("//jobId")->value();
                printf STDERR "JobID: %s\n", $jobId;
                $c->send_status_line;
                $c->send_header( "Content-type", "text/plain" );
                printf $c "\nJobID: %s\n", $jobId;
            } else {
                $c->send_status_line(404);
                $c->send_header( "Content-type", "text/plain" );
                print $c "\nUnknown call\n\n";
            }
        }
        $c->close;
        undef($c);
        exit;
    }
}

