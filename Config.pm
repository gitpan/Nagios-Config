package Nagios::Config ;

use strict ;
use warnings ;
use Carp ; 
use Data::Dumper ; 
use Nagios::Config::File ;
use Nagios::Config::ObjectFile ;

$Nagios::Config::VERSION = '0.02';


=head1 NAME

Nagios::Config - Parse Nagios configuration files

=head1 SYNOPSIS

  use Nagios::Config ;
  my $nc = new Nagios::Config("/usr/local/nagios/etc/nagios.cfg") ;
  foreach my $object ($nc->get_objects('host')){
    print $object->get('host_name') . "\n" ;
  }

=head1 DESCRIPTION

C<Nagios::Config> parses the Nagios configuration files in order to extract 
all information about nagios.cfg, resource.cfg and template-based objects. All 
template values are merged recursively, meaning that each object has all its 
attributes present, even those that were defined in templates.

Note: C<Nagios::Config> assumes that your Nagios configuration is valid
and may react unexpectedly if it is not. Please check your configuration
using the "nagios -v" command prior to using C<Nagios::Config> on it.

=cut


=head1 CONSTRUCTOR

=over 4

=item new ([FILE])

Creates a C<Nagios::Config>, which will parse the contents of C<FILE> assuming
it is a Nagios Main Configuration File. C<FILE> can be a file name or a reference
to an already opened filehandle. If C<FILE> is false, it will default to 
"/usr/local/nagios/etc/nagios.cfg"

=back

=cut
sub new {
	my $class = shift ;
	my $nagios_cfg = shift || "/usr/local/nagios/etc/nagios.cfg" ;

	my $this = {
		class => $class,
	} ;
	bless($this, $class) ;

	$this->{nagios_cfg} = new Nagios::Config::File($nagios_cfg) ;
	$this->{resource_cfg} = new Nagios::Config::File(
		$this->{nagios_cfg}->get_attr('resource_file')) ;

	my @object_files = () ;
	my $cfg_files = $this->{nagios_cfg}->get_attr('cfg_file') ;
	my $cfg_dirs = $this->{nagios_cfg}->get_attr('cfg_dir') ;
	if ($cfg_files){
		push @object_files, map {
			new Nagios::Config::ObjectFile($_) ;
		} @{$cfg_files} ;
	}
	if ($cfg_dirs){
		push @object_files, map { 
			map {new Nagios::Config::ObjectFile($_) ;} <$_/*.cfg> ;
		} @{$cfg_dirs} ;
	}
	$this->{object_files} = \@object_files ;

	$this->merge_templates() ;

	return $this ;
}
									

=head1 METHODS

=over 4

=item get_object_types ()

Returns a list of all the object types that where encountered during
the parse.

Ex: my @types = $nc->get_object_types() ;

=cut
sub get_object_types {
	my $this = shift ;

	return Nagios::Config::ObjectFile::get_seen_types() ;
}


=item get_object_files ()

Returns a list of all the template object files (as C<Nagios::Config::ObjectFile> 
objects) that where parsed.

Ex: my @files = $nc->get_object_files() ;

=cut
sub get_object_files {
	my $this = shift ;

	return @{$this->{object_files}} ;
}


=item get_objects ([TYPE])

Returns a list of all the objects of type C<TYPE> that where found during the 
parse. 
Each of these objects will be blessed in the Nagios::Config::Object::C<TYPE>
package, which inherits from Nagios::Config::Object.

Ex: my @hosts = $nc->get_objects('host') ;

=cut
sub get_objects {
	my $this = shift ;
	my $type = shift ;

	return map { 
		$_->get_objects($type) ;
	} @{$this->{object_files}} ;
}


=item get_object_hash ([TYPE], [KEY])

Returns a hash of all the objects of type C<TYPE> that where found during 
the parse, using attribute C<KEY> as the hash key. Make sure that the value 
of C<KEY> is unique for each object, or else you will not get all the objects
in the hash. 
Each of these objects will be blessed in the Nagios::Config::Object::C<TYPE>
package, which inherits from Nagios::Config::Object.

Ex: my %hosts = $nc->get_object_hash('host', 'host_name') ;

=cut
sub get_object_hash {
	my $this = shift ;
	my $type = shift ;
	my $key_field = shift ;

	return map { 
		$_->get_object_hash($type, $key_field) ;
	} @{$this->{object_files}} ;
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

Ex: my %my_host_services = $nc->get_object_hash('service', 'host_name', 'my_host', 1) ;

=cut
sub find_objects {
	my $this = shift ;
	my $type = shift ;
	my $attr = shift ;
	my $query = shift ;
	my $split = shift ;

	return map { 
		$_->find_objects($type, $attr, $query, $split) ;
	} @{$this->{object_files}} ;
}


=item get_nagios_cfg ()

Returns the C<Nagios::Config::File> object corresponding to nagios.cfg.

=cut
sub get_nagios_cfg {
	my $this = shift ;

	return $this->{nagios_cfg} ;
}


=item get_resource_cfg ()

Returns the C<Nagios::Config::File> object corresponding to resource.cfg.

=cut
sub get_resource_cfg {
	my $this = shift ;

	return $this->{resource_cfg} ;
}


sub merge_templates {
	my $this = shift ;

	foreach my $type ($this->get_object_types()){
		my %templates = () ;
		foreach my $of ($this->get_object_files()){
			$of->remove_templates($type, \%templates) ;
		}
		
		# Now we have extracted all the templatesthe current
		# type. We must now merge the data into the existing objects.
		my $nb_merged = 1 ;
		while ($nb_merged > 0){
			$nb_merged = 0 ;
			foreach my $of ($this->get_object_files()){
				$nb_merged += $of->merge_templates($type, \%templates) ;
			}
		}
	}
}


sub dump {
	my $this = shift ;

	print STDERR Dumper($this) ;
}


1 ;


=back 

=head1 AUTHOR

Patrick LeBoutillier, patl@cpan.org

=head1 SEE ALSO

Nagios::Config::File, Nagios::Config::ObjectFile, Nagios::Config::Object

=cut

