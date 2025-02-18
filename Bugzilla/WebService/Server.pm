# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# Contributor(s): Marc Schumann <wurblzap@gmail.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::WebService::Server;
use strict;

use Bugzilla::Error;
use Bugzilla::Util qw(datetime_from);

use Scalar::Util qw(blessed);
use Digest::MD5 qw(md5_base64);

use Storable qw(freeze);

sub handle_login {
    my ($self, $class, $method, $full_method) = @_;
    # Throw error if the supplied class does not exist or the method is private
    ThrowCodeError('unknown_method', {method => $full_method}) if (!$class or $method =~ /^_/);

    # BMO - use the class and method as the name, instead of the cgi filename
    if (Bugzilla->metrics_enabled) {
        Bugzilla->metrics->name("$class $method");
    }

    eval "require $class";
    my $error = $@;
    warn "$error" if $error;
    ThrowCodeError('unknown_method', {method => $full_method}) if $error;
    return if ($class->login_exempt($method) 
               and !defined Bugzilla->input_params->{Bugzilla_login});
    Bugzilla->login();

    Bugzilla::Hook::process(
        'webservice_before_call',
        { 'method'  => $method, full_method => $full_method });
}

sub datetime_format_inbound {
    my ($self, $time) = @_;

    my $converted = datetime_from($time, Bugzilla->local_timezone);
    if (!defined $converted) {
        ThrowUserError('illegal_date', { date => $time });
    }
    $time = $converted->ymd() . ' ' . $converted->hms();
    return $time
}

sub datetime_format_outbound {
    my ($self, $date) = @_;

    return undef if (!defined $date or $date eq '');

    my $time = $date;
    if (blessed($date)) {
        # We expect this to mean we were sent a datetime object
        $time->set_time_zone('UTC');
    } else {
        # We always send our time in UTC, for consistency.
        # passed in value is likely a string, create a datetime object
        $time = datetime_from($date, 'UTC');
    }
    return $time->iso8601();
}

# ETag support
sub bz_etag {
    my ($self, $data) = @_;
    my $cache = Bugzilla->request_cache;
    if (defined $data) {
        # Serialize the data if passed a reference
        local $Storable::canonical = 1;
        $data = freeze($data) if ref $data;

        # Wide characters cause md5_base64() to die.
        utf8::encode($data) if utf8::is_utf8($data);

        # Append content_type to the end of the data
        # string as we want the etag to be unique to
        # the content_type. We do not need this for
        # XMLRPC as text/xml is always returned.
        if (blessed($self) && $self->can('content_type')) {
            $data .= $self->content_type if $self->content_type;
        }

        $cache->{'bz_etag'} = md5_base64($data);
    }
    return $cache->{'bz_etag'};
}

1;

=head1 NAME

Bugzilla::WebService::Server - Base server class for the WebService API

=head1 DESCRIPTION

Bugzilla::WebService::Server is the base class for the individual WebService API
servers such as XMLRPC, JSONRPC, and REST. You never actually create a
Bugzilla::WebService::Server directly, you only make subclasses of it.

=head1 FUNCTIONS

=over

=item C<bz_etag>

This function is used to store an ETag value that will be used when returning
the data by the different API server modules such as XMLRPC, or REST. The individual
webservice methods can also set the value earlier in the process if needed such as
before a unique update token is added. If a value is not set earlier, an etag will
automatically be created using the returned data except in some cases when an error
has occurred.

=back

=head1 SEE ALSO

L<Bugzilla::WebService::Server::XMLRPC|XMLRPC>, L<Bugzilla::WebService::Server::JSONRPC|JSONRPC>,
and L<Bugzilla::WebService::Server::REST|REST>.

=head1 B<Methods in need of POD>

=over

=item handle_login

=item datetime_format_outbound

=item datetime_format_inbound

=back
