use strict ;
use Test ;

BEGIN {
	plan(tests => 4) ;
}

use Nagios::Config ;

my $nc = new Nagios::Config("t/cfg/nagios.cfg") ;
ok(1) ;

my @hosts = $nc->get_objects('host') ;
ok($hosts[0]->get_attr('host_name'), 'localhost') ;

my %contacts = $nc->get_object_hash('contact', 'contact_name') ;
ok($contacts{patl}->get_attr('email'), 'patl@cpan.org') ;

my @support_srvcs = $nc->find_objects('service', 'contact_groups', qr/support/, 1) ;
ok($support_srvcs[0]->get_attr('service_description'), 'httpd') ;


