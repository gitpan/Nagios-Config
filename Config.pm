package Nagios::Config ;

use strict ;
use warnings ;
use Carp ; 

$Nagios::Config::VERSION = '0.01';


sub new {
	my $class = shift ;
	my $nagios_cfg = shift || "/usr/local/nagios/nagios.cfg" ;

	my $fh = undef ;
	if (ref($nagios_cfg)){
		$fh = $nagios_cfg ;
	}
	else{
		if (! open(CFG, "<$nagios_cfg")){
			croak("Can't open $nagios_cfg for reading: $!") ;
		}
		$fh = \*CFG ;
	}

	my @files = () ;
	while (<$fh>){
		if ($_ =~ /^\s*cfg_file\s*=\s*(.*?)\s*$/){
			push @files, $1 ;
		}
		elsif ($_ =~ /^\s*cfg_dir\s*=\s*(.*?)\s*$/){
			push @files, <$1/*.cfg> ;
		}
	}
	close($fh) ;

	my $this = {
		class => $class,
		files => \@files,
		objects => {},
		types => {},
	} ;
	bless($this, $class) ;

	$this->process_files() ;
	$this->merge_templates() ;

	return $this ;
}


sub process_files {
	my $this = shift ;

	foreach my $f (@{$this->{files}}){
		if (! open(CFG, "<$f")){
			croak("Can't open $f for reading: $!") ;
		}
	
		my $in = 0 ;
		my $type = '' ;
		my $obj = undef ;
		while (<CFG>){
			my $line = $_ ;
			$line =~ s/^\s+// ;
			$line =~ s/\s+$// ;

			if ($line eq ''){
				next ;
			}
			elsif ($line =~ /^#/){
				next ;
			}
			elsif ($line =~ /^define\s+(\w+)\s*{$/){
				$type = $1 ;
				if (! exists($this->{types}->{$type})){
					no strict 'refs' ;
					my @I = @{$this->{class} . "::Object::" . $type . "::ISA"} ;
					my $found = 0 ;
					foreach my $i (@I){
						if ($i eq 'Nagios::Config::Object'){
							$found = 1 ;
							last ;
						}
					}
					if (! $found){
						push @{$this->{class} . "::Object::" . $type . "::ISA"}, 'Nagios::Config::Object' ;
					}
				}
				$this->{types}->{$type}++ ;
				$obj = bless({}, $this->{class} . "::Object::$type") ;
				$in = 1 ;
			}
			elsif (($in)&&($line =~ /(\w+)\s+(.*?)$/)){
				# We have a property definition
				$obj->{$1} = $2 ;				
			}
			elsif (($in)&&($line eq '}')){
				$in = 0 ;
				push @{$this->{objects}->{$type}}, $obj ;
			}
		}
		close(CFG) ;				
	}
}


sub merge_templates {
	my $this = shift ;

	foreach my $t (keys %{$this->{types}}){
		my %templates = () ;

		foreach my $o (@{$this->{objects}->{$t}}){
			if ((defined($o->{register}))&&($o->{register} eq "0")){
				$templates{$o->{name}} = $o ;
				$o = undef ;
			}
		}
		for (my $i = 0 ; $i < scalar(@{$this->{objects}->{$t}}) ; $i++){
			if (! defined($this->{objects}->{$t}->[$i])){
				splice(@{$this->{objects}->{$t}}, $i, 1) ;
				$i-- ;
			}
		}

		my $nb_merged = 1 ;
		while ($nb_merged > 0){
			$nb_merged = 0 ;
			foreach my $o (@{$this->{objects}->{$t}}){
				if (exists($o->{use})){
					my $tname = $o->{use} ;
					delete $o->{use} ;
					delete $templates{$tname}->{name} ;
					delete $templates{$tname}->{register} ;
					my %t = (%{$templates{$tname}}, %{$o}) ;
					$o = bless(\%t, $this->{class} . "::Object::$t") ;
					$nb_merged++ ;
				}
			}
		}
	}
}


sub get_objects {
	my $this = shift ;
	my $type = shift ;

	if (exists($this->{objects}->{$type})){
		return @{$this->{objects}->{$type}} ;
	}

	return () ;
}


sub get_files {
	my $this = shift ;

	return @{$this->{files}} ;
}


sub get_types {
	my $this = shift ;

	return @{$this->{types}} ;
}



package Nagios::Config::Object ;

sub get_attr {
	my $this = shift ;
	my $name = shift ;
	my $split = shift || 0 ;

	my $val = $this->{$name} ;
	return ($split ? split(/\s*,\s*/, $val) : $val) ;
}


sub get {
	my $this = shift ;
	my $name = shift ;
	my $split = shift ;

	return $this->get_attr($name, $split) ;
}


1 ;



__END__
=head1 NAME

Nagios::Config - Parse Nagios configuration files

=head1 SYNOPSIS

  use Nagios::Config ;
  my $nc = new Nagios::Config("/usr/local/nagios/nagios.cfg") ;
  foreach ($nc->get_objects('host')){
    print $_->get('host_name') . "\n" ;
  }

=head1 DESCRIPTION

C<Nagios::Config> allows you to the main Nagios configuration file in order
to extract all information about template-based objects. All template values
are merged recursively, meaning that each object has all its attributes present,
even those that were defined in templates.

Note: Only the template-based objects are parsed, not the attributes
directly present in nagios.cfg, resource.cfg or cgi.cfg.

Note: C<Nagios::Config> assumes that your Nagios configuration is valid
and may react unexpectedly if it is not. Please check your configuration
using the "nagios -v" command prior to using C<Nagios::Config> on it.

=head1 CONSTRUCTOR

=over 4

=item new ([FILE])

Creates a C<Nagios::Config>, which will parse the contents of C<FILE> assuming
it is a Nagios Main Configuration File. C<FILE> can be a file name or a reference
to an already opened filehandle. If C<FILE> is false, it will default to /usr/local/nagios/nagios.cfg

=back

=head1 METHODS

=over 4

=item get_types ()

Returns a list of all the object types that where encountered during
the parse.

Ex: my @types = $nc->get_types() ;

=item get_files ()

Returns a list of all the template object files that where parsed.

Ex: my @files = $nc->get_files() ;

=item get_objects ([TYPE])

Returns a list of all the objects of type C<TYPE> that where found during
the parse. Each of these objects will be blessed in the Nagios::Config::Object::C<TYPE>
package, which inherits from Nagios::Config::Object. See the SUBCLASSING section
below for more information on how to change this behaviour.

Ex: my @hosts = $nc->get_objects('host') ;

=back

=head1 OBJECTS

Each object returned by C<Nagios::Config> provides the following methods
to access its data:

=over 4

=item get_attr ([NAME], [SPLIT])

If C<SPLIT> is false, returns the value for the attribute named C<NAME> from the current object.

If C<SPLIT> is true, returns the value split using /\s*,\s*/. This is useful for
attributes that can have multiple values.

Ex:
  # define host {
  #   host_name h1, h2, h3
  # }
  my $val = $host->get_attr('host_name') ;     
  # $val = 'h1, h2, h3'
  my @vals = $host->get_attr('host_name', 1) ; 
  # @vals = ('h1', 'h2', 'h3')

=item get ([NAME], [SPLIT])

A shortcut for get_attr().

=back 

=head1 SUBCLASSING

If you which to change or extend the functionality in the classes provided by C<Nagios::Config>,
you must do 2 things:

  1) Subclass C<Nagios::Config>
  2) Subclass C<Nagios::Config::Object>

This will cause the objects to be blessed in the MyNC::Object::C<TYPE> packages.
To implement these packages in advance, make them inherit from MyNC::Object.

Here is an example:

  use Nagios::Config ;

  package MyNC ;
  @MyNC::ISA = qw(Nagios::Config) ;

  package MyNC::Object ;
  @MyNC::Object::ISA = qw(Nagios::Config::Object) ;

  package MyNC::Object::host ;
  @MyNC::Object::host::ISA = qw(MyNC::Object) ;

  sub get {
    my $this = shift ;
    my $name = shift ;

    return "host is " . $this->SUPER::get($name) ;
  }


  package main ;

  my $mnc = MyNC->new("/usr/local/nagios/nagios.cfg") ;
  print $mnc->get_objects('host')->[0]->get('host_name') ; # host is ...

=head1 AUTHOR

Patrick LeBoutillier, patl@cpan.org

=head1 SEE ALSO

perl(1).

=cut
