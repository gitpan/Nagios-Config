use Test ;
use Data::Dumper ;

BEGIN {
	plan(tests => 4) ;
}

use Nagios::Config ;
ok(1) ;

my $nc = new Nagios::Config(\*DATA) ;
# print STDERR Dumper($nc) ;
ok(2) ;
my @hosts = $nc->get_objects('host') ;
my $host = $hosts[0] ;
ok($host->get('check_command'), 'check_host') ;
ok($host->get('notification_options'), 'd,u,r') ;
my @opt = $host->get('notification_options', 1) ;
ok($opt[0], 'd') ;


__END__

cfg_file=test.cfg
