#!/usr/bin/perl

use strict;
#use warnings;

#use File::Tail;
use File::LogReader;
use English qw( -no_match_vars );
use Carp qw( carp croak );
use Readonly;
use URI::Split qw(uri_split);
use YAML qw(LoadFile);

use MongoDB;
use MongoDB::OID;

our $VERSION = '0.3';

#
# Default values for database connection parameters
#
Readonly my $DEFAULT_HOST     	=> 'localhost';
Readonly my $DEFAULT_DATABASE 	=> 'hoplogs';
Readonly my $DEFAULT_COLLECTION => 'squid_log';
Readonly my $DEFAULT_USER     	=> 'squid';
Readonly my $DEFAULT_LOGFILE 	=> '/var/log/squid3/access.log';
#
# Default path of configuration file
#
Readonly my $DEFAULT_CONFIGFILE => '/etc/squid3/log_mysql_daemon.conf';


#
# Global variables
#

# database connection parameters
my ( $host, $database, $collection, $user, $pass, $file, $customer_oid );


# config hash
my $config;

# database connection
my $dbh;

# prepared insert statement
my $sth;


#
# Subroutines
#

#
# log_info
#
# utility routine to print messages on stderr (so they appear in cache log)
# without using warn, which would clutter the log with source line numbers
#
sub log_info {
    my $msg = shift;
    print STDERR "$msg\n";
    return;
}



#
# load configuration file
#
sub load_config {
    my $config_file = shift || $DEFAULT_CONFIGFILE;

    log_info("Configuration file: $config_file");

    eval {
        $config = LoadFile($config_file);

        $host = $config->{host};
        $database = $config->{database};
        $collection = $config->{collection};
        $user = $config->{user};
        $pass = $config->{pass};
		$file = $config->{file};
		$customer_oid = MongoDB::OID->new( value => $config->{customer_oid});
    };
    if ($EVAL_ERROR) {
        carp("Error loading config file: $EVAL_ERROR");
    }

    if ( !$host ) {
        $host = $DEFAULT_HOST;
        log_info("Database host not specified. Using '$host'.");
    }
    else {
        log_info("Database host: '$host'");
    }

    if ( !$database ) {
        $database = $DEFAULT_DATABASE;
        log_info("Database name not specified. Using '$database'.");
    }
    else {
        log_info("Database: '$database'");
    }
           
    if ( !$collection ) {
        $collection = $DEFAULT_COLLECTION;
        log_info("Collection parameter not specified. Using '$collection'.");
    }
    else {
        log_info("Collection: '$collection'");
    }
            
    if ( !$user ) {
        $user = $DEFAULT_USER;
        log_info("User parameter not specified. Using '$user'.");
    }
    else {
        log_info("User: '$user'");
    }

    if ( !$pass ) {
        log_info('No password specified. Connecting with NO password.');
    }
    else {
        log_info("Pass: (hidden)");
    }

	if ( !$file ) {
		$file = $DEFAULT_LOGFILE;	
		log_info("No access log file specified. Reading '$file'.");
	}
	else {
		log_info("File: '$file'");
	}
	

    return;
}
              

#
# db_connetct()
#
# Perform database connection
# returns database handle
# or croak()s on error
#
sub db_connect {
	my $conn;
    eval {
        log_info("Connecting...");
        $conn = MongoDB::Connection->new( host => $host );
        carp 'Connected.';
    };
    if ($EVAL_ERROR) {
        croak "Cannot connect to database: $EVAL_ERROR";
    }

    $dbh = $conn->$database;

    return $dbh;
}



# The script is passed only one argument:
# the path to the configuration file
sub main {
    my $arg = shift;

    load_config($arg);

	db_connect();

	my $coll = $dbh->$collection;

    # for better performance, prepare the statement at startup

    #
    # main loop
    #
	carp 'Reading file...';
	my $logfile = File::LogReader->new( filename => $file);
	while (defined(my $line = $logfile->read_line)) {
		chomp $line;

        my @values = split / \s+ /xms, $line;

        my ($scheme, $domain, $path, $query, $frag) = uri_split($values[6]);
        $values[6] = $domain || $scheme;
        #carp "scheme='$scheme' | domain='$domain' | path='$path' | query='$query' | frag='$frag'";
		push @values, $customer_oid;
		my %row_hash = (
							timestamp		=>	$values[0],
							responsetime	=>	$values[1],
							src_ip			=>	$values[2],
							request_status	=>  (split(/\//, $values[3]))[0],
							status_code		=>	(split(/\//, $values[3]))[1],
							reply_size		=>	$values[4],
							request_method	=>	$values[5],
							request_domain	=>	$values[6],
							request_path	=>	$path,
							username		=>	$values[7],
							hier_status		=>	(split(/\//, $values[8]))[0],
							server_ip		=>	(split(/\//, $values[8]))[1],
							mime_type		=>	(split(/\//, $values[9]))[0],
							mime_sub_type	=>  (split(/\//, $values[9]))[1],
							customerid		=>	$values[10]
					);

            eval {                          # catch db errors to avoid crashing squid in case something goes wrong...
				$coll->insert( \%row_hash );
            };
           if ( $EVAL_ERROR ) {
               # leave a trace of the error in cache.log, but don't kill this script with croak...
               carp $EVAL_ERROR . " values=(" . join(', ', @values) . ')';

           }
    }

    $sth->finish;
    $dbh->disconnect();

    return;
}


=head2 Configuration file

The configuration file contains the database connection parameters, written as key: value pairs, one per line.

Example:

  host: localhost
  database: hoplogs
  collection: squid
  user: squid
  pass: 123456

(It's a YAML file.)

=over 4

=item host

Host where the mysql server is running. If unspecified, 'localhost' is assumed.

=item database

Name of the database to connect to. If unspecified, 'squid_log' is assumed.

=item table

Name of the database table where log lines are stored. If unspecified, 'access_log' is assumed.

=item username

Username to use when connecting to the database. If unspecified, 'squid' is assumed.

=item password

Password to use when connecting to the database. If unspecified, no password is used.

=back

To leave all fields to their default values, just create the configuration file and don't write anything in it.

To only specify the database password, put this single line in the configuration file:

  pass: <password>

=head3 Security note

This file should be owned by root and its permission bits should be set to 600.

=head1 BUGS & TODO

=head2 Squid version

=head1 CHANGELOG

=head1 AUTHOR

Nishant Sharma, codemarauder@gmail.com

Modified the original script by Marcello Romani which used to insert logs
into MySQL DB. This version inserts the logs to MongoDB.

=head1 ORIGINAL AUTHOR

Marcello Romani, marcello.romani@libero.it

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Marcello Romani

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
