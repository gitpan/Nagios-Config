package Nagios::Config::File ;

use strict ;
use warnings ;
use Carp ; 
use Data::Dumper ; 


my %DUPLICATES_ALLOWED = (
	cfg_file => 1,
	cfg_dir => 1,
) ;


=head1 NAME

Nagios::Config::File - Base class for Nagios configuration files

=head1 SYNOPSIS

  use Nagios::Config ;
  my $nc = new Nagios::Config("/usr/local/nagios/etc/nagios.cfg") ;
  my $resource = $nc->get_resource_cfg() ; 
  print $resource->get_attr('$USER1$') . "\n" ;

=head1 DESCRIPTION

C<Nagios::Config::File> is the base class for all Nagios configuration
files. You should not need to create these yourself.

=cut


=head1 CONSTRUCTOR

=over 4

=item new ([FILE])

Creates a C<Nagios::Config::File>.

=back

=cut
sub new {
	my $class = shift ;
	my $file = shift ;

	my $this = {} ;
	bless($this, $class) ;

	my $fh = undef ;
	if (ref($file)){
		$fh = $file ;
	}
	else{
		if (! open(CFG, "<$file")){
			croak("Can't open $file for reading: $!") ;
		}
		$fh = \*CFG ;
		$this->{file} = $file ;
	}


	$this->{attrs} = {} ;
	$this->{fh} = $fh ;

	$this->parse() ;
	close($fh) ;

	return $this ;
}


sub parse {
	my $this = shift ;

	my $fh = $this->{fh} ;
	while (<$fh>){
		my $line = $this->strip($_) ;

		if ($this->is_comment($line)){
			next ;
		}
		elsif (my ($name, $value) = $this->is_attribute($line)){
			if ($DUPLICATES_ALLOWED{$name}){
				push @{$this->{attrs}->{$name}}, $value ;
			}
			else{
				$this->{attrs}->{$name} = $value ;
			}
		}
	}
}


sub strip {
	my $this = shift ;
	my $line = shift ;

	$line =~ s/^\s+// ;
	$line =~ s/\s+$// ;

	return $line ;
}


sub is_comment {
	my $this = shift ;
	my $line = shift ;

	if (($line eq '')||($line =~ /^#/)){
		return 1 ;
	}
	
	return 0 ;
}


sub is_attribute {
	my $this = shift ;
	my $line = shift ;

	if ($line =~ /^([\w\$]+)\s*=\s*(.+)$/){
		return ($1, $2) ;
	}
	
	return () ;
}


=head1 METHODS

=over 4

=item get_attr ([NAME], [SPLIT])

Returns the value of the attribute C<NAME> for the current file.
If C<SPLIT> is true, returns a list of all the values split on
/\s*,\s*/. This is useful for attributes that can have more that one value.

=cut
sub get_attr {
	my $this = shift ;
	my $name = shift ;
	my $split = shift || 0 ;

	my $val = $this->{attrs}->{$name} ;
	return ($split ? split(/\s*,\s*/, $val) : $val) ;
}


=item get_file ()

Returns the filename for the current object.

=cut
sub get_file {
	my $this = shift ;

	return $this->{file} ;
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

Nagios::Config, Nagios::Config::Object, Nagios::Config::ObjectFile

=cut


