package Nagios::Config::ObjectFile ;
@ISA = qw(Nagios::Config::File) ;

use strict ;
use warnings ;
use Carp ; 
use Data::Dumper ; 
use Nagios::Config::Object ;


my %SEEN_TYPES = () ;


=head1 NAME

Nagios::Config::Onject - Class for Nagios object configuration files

=head1 SYNOPSIS

  use Nagios::Config ;
  my $nc = new Nagios::Config("/usr/local/nagios/etc/nagios.cfg") ;
  my @object_files = $nc->get_object_files() ; 
  foreach (@object_files){
    my @hosts = $_->get_objects('host') ;
    foreach my $h (@hosts){
      print $h->get_attr('host_name') . "\n" ;
    }
  }

=head1 DESCRIPTION

C<Nagios::Config::ObjectFile> is the class for all Nagios object 
configuration files. You should not need to create these yourself.

=cut


=head1 CONSTRUCTOR

=over 4

=item new ([FILE])

Creates a C<Nagios::Config::ObjectFile>.

=back

=cut
sub new {
	my $class = shift ;
	my $file = shift ;

	my $this = $class->SUPER::new($file) ;

	return $this ;
}


sub parse {
	my $this = shift ;

	my $fh = $this->{fh} ;
	my $type = undef ;
	my $obj = undef ;
	my $in = 0 ;
	while (<$fh>){
		my $line = $this->strip($_) ;

		if ($this->is_comment($line)){
			next ;
		}
		elsif (my $ntype = $this->is_definition($line)){
			$type = $ntype ;
			if (! exists($SEEN_TYPES{$type})){
				no strict 'refs' ;
				my $isa_name = "Nagios::Config::Object::" . $type . "::ISA" ;
				my @I = @{$isa_name} ;
				my $found = 0 ;
				foreach my $i (@I){
					if ($i eq 'Nagios::Config::Object'){
						$found = 1 ;
						last ;
					}
				}
				if (! $found){
					push @{$isa_name}, 'Nagios::Config::Object' ;
				}
			}
			$SEEN_TYPES{$type}++ ;
			my $module = "Nagios::Config::Object::" . $type ;
			$obj = $module->new() ;
			$in = 1 ;
		}
		elsif (($in)&&(my ($name, $value) = $this->is_attribute($line))){
			# We have a property definition
			$obj->{$name} = $value ;				
		}
		elsif (($in)&&($line eq '}')){
			$in = 0 ;
			push @{$this->{objects}->{$type}}, $obj ;
		}
	}
}


sub is_attribute {
	my $this = shift ;
	my $line = shift ;

	if ($line =~ /^([\w\$]+)\s+(.+)$/){
		return ($1, $2) ;
	}
	
	return () ;
}


sub is_definition {
	my $this = shift ;
	my $line = shift ;

	if ($line =~ /^define\s+(\w+)\s*{$/){
		return $1 ;
	}
	
	return ;
}


=head1 METHODS

=over 4

=item get_objects ([TYPE])

Returns a list of all the objects of type C<TYPE> that where found during the 
parse. 
Each of these objects will be blessed in the Nagios::Config::Object::C<TYPE>
package, which inherits from Nagios::Config::Object.

Ex: my @hosts = $of->get_objects('host') ;

=cut
sub get_objects {
	my $this = shift ;
	my $type = shift ;
	
	my $objs = $this->{objects}->{$type} ;
	if ($objs){
		@{$objs} ;
	}
	else {
		() ;
	}
}


=item get_object_hash ([TYPE], [KEY])

Returns a hash of all the objects of type C<TYPE> that where found during 
the parse, using attribute C<KEY> as the hash key. Make sure that the value 
of C<KEY> is unique for each object, or else you will not get all the objects
in the hash. 
Each of these objects will be blessed in the Nagios::Config::Object::C<TYPE>
package, which inherits from Nagios::Config::Object.

Ex: my %hosts = $of->get_object_hash('host', 'host_name') ;

=cut
sub get_object_hash {
	my $this = shift ;
	my $type = shift ;
	my $key_field = shift || ($type . "_name") ;

	my $objs = $this->{objects}->{$type} ;
	if ($objs){
		map {
			($_->get_attr($key_field), $_) ;
		} @{$objs} ;
	}
	else {
		() ;
	}
}


=item find_objects ([TYPE], [ATTR], [QUERY], [SPLIT])

Returns a list of all the objects of type C<TYPE> that where found during
the parse, where C<ATTR> "matches" C<QUERY>. C<QUERY> can be a regular expression
(i.e. qr/.../) or a scalar. If C<SPLIT> is true, the values will be split
on /\s*,\s*/ and each of the resulting values will be compared separately.
Also, if the value of the C<ATTR> is '*', the object is returned regardless
of the value of C<QUERY>.
Each of these objects will be blessed in the Nagios::Config::Object::C<TYPE>
package, which inherits from Nagios::Config::Object.

Ex: my %services = $of->get_object_hash('service', 'host_name', 'my_host', 1) ;

=cut
sub find_objects {
	my $this = shift ;
	my $type = shift ;
	my $attr = shift ;
	my $query = shift ;
	my $split = shift ;

	my $objs = $this->{objects}->{$type} ;
	if ($objs){
		map {
			my $obj = $_ ;
			my @avs = $obj->get_attr($attr, $split) ;
			if (UNIVERSAL::isa($query, 'Regexp')){
				map {((($_ eq '*')||($_ =~ $query)) ? ($obj) : ())} @avs ;
			}
			else{
				map {((($_ eq '*')||($_ eq $query)) ? ($obj) : ())} @avs ;
			}			
		} @{$objs} ;
	}
	else {
		() ;
	}
}


sub remove_templates {
	my $this = shift ;
	my $type = shift ;
	my $templates = shift ;

	if (! defined($this->{objects}->{$type})){
		return () ;
	}

	for (my $i = 0 ; $i < scalar(@{$this->{objects}->{$type}}) ; $i++){
		my $o = $this->{objects}->{$type}->[$i] ;
		my $reg = $o->get_attr('register') ;
		if ((defined($reg))&&($reg eq "0")){
			$templates->{$o->get_attr('name')} = $o ;
			splice(@{$this->{objects}->{$type}}, $i, 1) ;
			$i-- ;
		}
	}
}


sub merge_templates {
	my $this = shift ;
	my $type = shift ;
	my $templates = shift ;

	if (! defined($this->{objects}->{$type})){
		return 0 ;
	}

	my $nb_merged = 0 ;
	foreach my $o (@{$this->{objects}->{$type}}){
		my $use = $o->get_attr('use') ;
		if (defined($use)){
			my $tname = $use ;
			delete $o->{use} ;
			delete $templates->{$tname}->{name} ;
			delete $templates->{$tname}->{register} ;
			my %t = (%{$templates->{$tname}}, %{$o}) ;
			$o = bless(\%t, $o->{class}) ;
			$nb_merged++ ;
		}
	}

	return $nb_merged ;
}


sub get_seen_types {
	return keys %SEEN_TYPES ;
}


1 ;


=back 

=head1 AUTHOR

Patrick LeBoutillier, patl@cpan.org

=head1 SEE ALSO

Nagios::Config, Nagios::Config::Object, Nagios::Config::File

=cut



