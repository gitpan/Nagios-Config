package Nagios::Config::Object ;

use strict ;


=head1 NAME

Nagios::Config::Object - Base class for Nagios configuration objects

=head1 SYNOPSIS

  use Nagios::Config ;
  my $nc = new Nagios::Config("/usr/local/nagios/etc/nagios.cfg") ;
  foreach my $object ($nc->get_objects('host')){
    print $object->get('host_name') . "\n" ;
  }

=head1 DESCRIPTION

C<Nagios::Config::Object> is the base class for all Nagios configuration
objects. You should not need to create these yourself.

=cut


=head1 CONSTRUCTOR

=over 4

=item new ([FILE])

Creates a C<Nagios::Config::Object>.

=back

=cut
sub new {
	my $class = shift ;
	
	my $this = {
		class => $class
	} ;
	bless($this, $class) ;
	
	return $this ;
}


=head1 METHODS

=over 4

=item get_attr ([NAME], [SPLIT])

Returns the value of the attribute C<NAME> for the current object.
If C<SPLIT> is true, returns a list of all the values split on
/\s*,\s*/. This is useful for attributes that can have more that one value.

Ex: my $value = $host_obj->get_attr('notification_period') ;

Ex: my @values = $service_obj->get_attr('host_name', 1) ;

=cut
sub get_attr {
	my $this = shift ;
	my $name = shift ;
	my $split = shift || 0 ;

	my $val = $this->{$name} ;
	return ($split ? split(/\s*,\s*/, $val) : $val) ;
}


1 ;


=back 

=head1 AUTHOR

Patrick LeBoutillier, patl@cpan.org

=head1 SEE ALSO

Nagios::Config, Nagios::Config::File, Nagios::Config::ObjectFile

=cut

