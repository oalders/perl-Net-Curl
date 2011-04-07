package WWW::CurlOO::Compat;
=head1 NAME

WWW::CurlOO::Compat -- compatibility layer for WWW::Curl

=head1 SYNOPSIS

 BEGIN { eval { require WWW::CurlOO::Compat; } }

 use WWW::Curl::Easy;

=cut

use strict;
use warnings;

my @packages = qw(
	WWW/Curl.pm
	WWW/Curl/Easy.pm
	WWW/Curl/Form.pm
	WWW/Curl/Multi.pm
	WWW/Curl/Share.pm
);

# mark fake packages as loaded
@INC{ @packages } = ("WWW::CurlOO::Compat") x scalar @packages;

# copies constants to current namespace
sub _copy_constants
{
	my $EXPORT = shift;
	my $dest = shift . "::";
	my $source = shift;

	no strict 'refs';
	my @constants = grep /^CURL/, keys %{ "$source" };
	push @$EXPORT, @constants;

	foreach my $name ( @constants ) {
		*{ $dest . $name } = \*{ $source . $name};
	}
}



package WWW::Curl;

use WWW::CurlOO ();

our $VERSION = '4.15';

package WWW::Curl::Easy;

use WWW::CurlOO ();
use WWW::CurlOO::Easy ();
use Exporter ();
our @ISA = qw(WWW::CurlOO::Easy Exporter);

our $VERSION = '4.15';
our @EXPORT;

BEGIN {
	# in WWW::Curl almost all the constants are thrown into WWW::Curl::Easy
	foreach my $pkg ( qw(WWW::CurlOO:: WWW::CurlOO::Easy::
			WWW::CurlOO::Form:: WWW::CurlOO::Share::
			WWW::CurlOO::Multi::) ) {
		WWW::CurlOO::Compat::_copy_constants(
			\@EXPORT, __PACKAGE__, $pkg );
	}
}

# for now new() behaves in a compatible manner,
# on error in future versions
#sub new {}

*init = \&WWW::CurlOO::Easy::new;
*errbuf = \&WWW::CurlOO::Easy::error;

*version = \&WWW::CurlOO::version;

sub cleanup { 0 };

sub internal_setopt { die };

# there is a bug in CurlOO duphandle - 
sub duphandle
{
	my ( $source ) = @_;
	my $clone = $source->SUPER::duphandle;
	bless $clone, "WWW::Curl::Easy"
}

sub const_string
{
	my ( $self, $constant ) = @_;
	return constant( $constant );
}

# this thing is weird !
sub constant
{
	my $name = shift;
	undef $!;
	my $value = eval "$name()";
	if ( $@ ) {
		require POSIX;
		$! = POSIX::EINVAL();
		return undef;
	}
	return $value;
}

sub setopt
{
	# convert options and provide wrappers for callbacks
	my ($self, $option, $value, $push) = @_;

	if ( $push ) {
		return $self->pushopt( $option, $value );
	}

	if ( $option == CURLOPT_PRIVATE ) {
		# stringified
		$self->{private} = "$value";
		return 0;
	} elsif ( $option == CURLOPT_ERRORBUFFER ) {
		# I don't even know how was that supposed to work, but it does
		$self->{errorbuffer} = $value;
		return 0;
	}

	# wrappers for callbacks
	if ( $option == CURLOPT_WRITEFUNCTION ) {
		my $sub = $value;
		$value = sub {
			my ( $easy, $data, $uservar ) = @_;
			return $sub->( $data, $uservar );
		};
	} elsif ( $option == CURLOPT_HEADERFUNCTION ) {
		my $sub = $value;
		$value = sub {
			my ( $easy, $data, $uservar ) = @_;
			return $sub->( $data, $uservar );
		};
	} elsif ( $option == CURLOPT_READFUNCTION ) {
		my $sub = $value;
		$value = sub {
			my ( $easy, $maxlen, $uservar ) = @_;
			return $sub->( $maxlen, $uservar );
		};
	} elsif ( $option == CURLOPT_PROGRESSFUNCTION ) {
		my $sub = $value;
		$value = sub {
			my ( $easy, $dltotal, $dlnow, $ultotal, $ulnow, $uservar ) = @_;
			return $sub->( $uservar, $dltotal, $dlnow, $ultotal, $ulnow );
		};
	} elsif ( $option == CURLOPT_DEBUGFUNCTION ) {
		my $sub = $value;
		$value = sub {
			my ( $easy, $type, $data, $uservar ) = @_;
			return $sub->( $data, $uservar, $type );
		};
	}
	eval {
		$self->SUPER::setopt( $option, $value );
	};
	unless ( $@ ) {
		return 0;
	}
	if ( ref $@ eq "WWW::CurlOO::Easy::Code" ) {
		return 0+$@;
	}
	die $@;
}

sub pushopt
{
	my ($self, $option, $value) = @_;
	eval {
		$self->SUPER::pushopt( $option, $value );
	};
	unless ( $@ ) {
		return 0;
	}
	if ( ref $@ eq "WWW::CurlOO::Easy::Code" ) {
		# WWW::Curl allows to use pushopt on non-slist arguments
		if ( $@ == CURLE_BAD_FUNCTION_ARGUMENT ) {
			return $self->setopt( $option, $value );
		}
		return 0+$@;
	}
	die $@;
}

sub getinfo
{
	my ($self, $option) = @_;

	my $ret;
	if ( $option == CURLINFO_PRIVATE ) {
		$ret = $self->{private};
	} else {
		eval {
			$ret = $self->SUPER::getinfo( $option );
		};
		if ( $@ and ref $@ eq "WWW::CurlOO::Easy::Code" ) {
			return undef;
		} elsif ( $@ ) {
			die $@;
		}
	}
	if ( @_ > 2 ) {
		$_[2] = $ret;
	}
	return $ret;
}

sub perform
{
	my $self = shift;
	eval {
		$self->SUPER::perform( @_ );
	};
	if ( defined $self->{errorbuffer} ) {
		my $error = $self->error();

		# copy error message to specified global variable
		no strict 'refs';
		*{ "main::" . $self->{errorbuffer} } = \$error;
	}
	unless ( $@ ) {
		return 0;
	}
	if ( ref $@ eq "WWW::CurlOO::Easy::Code" ) {
		return 0+$@;
	}
	die $@;
}


package WWW::Curl::Form;
use WWW::CurlOO ();
use WWW::CurlOO::Form ();
use Exporter ();
our @ISA = qw(WWW::CurlOO::Form Exporter);

our $VERSION = '4.15';

our @EXPORT;

BEGIN {
	WWW::CurlOO::Compat::_copy_constants(
		\@EXPORT, __PACKAGE__, "WWW::CurlOO::Form::" );
}

# this thing is weird !
sub constant
{
	my $name = shift;
	undef $!;
	my $value = eval "$name()";
	if ( $@ ) {
		require POSIX;
		$! = POSIX::EINVAL();
		return undef;
	}
	return $value;
}

sub formadd
{
	my ( $self, $name, $value ) = @_;
	return $self->add(
		CURLFORM_COPYNAME, $name,
		CURLFORM_COPYCONTENTS, $value
	);
}

sub formaddfile
{
	my ( $self, $filename, $description, $type ) = @_;
	return $self->add(
		CURLFORM_FILE, $filename,
		CURLFORM_COPYNAME, $description,
		CURLFORM_CONTENTTYPE, $type,
	);
}


package WWW::Curl::Multi;
use WWW::CurlOO ();
use WWW::CurlOO::Multi ();
our @ISA = qw(WWW::CurlOO::Multi);

sub add_handle
{
	my ( $multi, $easy ) = @_;
	eval {
		$multi->SUPER::add_handle( $easy );
	};
}

sub remove_handle
{
	my ( $multi, $easy ) = @_;
	eval {
		$multi->SUPER::remove_handle( $easy );
	};
}

sub info_read
{
	my ( $multi ) = @_;
	my @ret;
	eval {
		@ret = $multi->SUPER::info_read();
	};
	return () unless @ret;

	my ( $msg, $easy, $result ) = @ret;
	$multi->remove_handle( $easy );

	return ( $easy->{private}, $result );
}

sub fdset
{
	my ( $multi ) = @_;
	my @vec;
	eval {
		@vec = $multi->SUPER::fdset;
	};
	my @out;
	foreach my $in ( @vec ) {
		my $max = 8 * length $in;
		my @o;
		foreach my $fn ( 0..$max ) {
			push @o, $fn if vec $in, $fn, 1;
		}
		push @out, \@o;
	}

	return @out;
}

sub perform
{
	my ( $multi ) = @_;

	my $ret;
	eval {
		$ret = $multi->SUPER::perform;
	};

	return $ret;
}

package WWW::Curl::Share;
use WWW::CurlOO ();
use WWW::CurlOO::Share ();
use Exporter ();
our @ISA = qw(WWW::CurlOO::Share Exporter);

our @EXPORT;

BEGIN {
	WWW::CurlOO::Compat::_copy_constants(
		\@EXPORT, __PACKAGE__, "WWW::CurlOO::Share::" );
}

# this thing is weird !
sub constant
{
	my $name = shift;
	undef $!;
	my $value = eval "$name()";
	if ( $@ ) {
		require POSIX;
		$! = POSIX::EINVAL();
		return undef;
	}
	return $value;
}

1;

=head1 COPYRIGHT

Copyright (c) 2011 Przemyslaw Iskra <sparky at pld-linux.org>.

You may opt to use, copy, modify, merge, publish, distribute and/or sell
copies of the Software, and permit persons to whom the Software is furnished
to do so, under the terms of the MPL or the MIT/X-derivate licenses. You may
pick one of these licenses.