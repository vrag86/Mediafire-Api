package Mediafire::Api;

use 5.008001;
use utf8;
use strict;
use warnings;
use open qw(:std :utf8);
use Carp qw/croak carp/;
use URI::Escape;
use LWP::UserAgent;
use File::Basename;
use HTTP::Request;
use JSON::XS;

use Mediafire::Api::UploadFile;

use Data::Printer;

our $VERSION = '0.01';

############################ PRIVATE METHODS ############################################

my $openMainPage = sub {
    # Open main page for set cookies
    my ($self) = @_;
    my $url = 'https://www.mediafire.com';
    my $res = $self->{ua}->get($url);
    my $code = $res->code;
    if ($code ne '200') {
        croak "Wrong response code from url: '$url'. Code: $code";
    }
    return 1;
};

my $getSessionToken = sub {
    my ($self) = @_;
    my $url = 'https://www.mediafire.com/apps/myfiles/?shared=0&multikeys=0';

    my %headers = (
        'referer'                   => 'https://www.mediafire.com/',
        'upgrade-insecure-requests' => '1',
    );

    my $res = $self->{ua}->get($url, %headers);
    my $code = $res->code;
    if ($code ne '200') {
        croak "Can't get session_token by url: '$url'. Code: $code";
    }
    my $body = $res->decoded_content;
    if ($body =~ /token=(.+?)['&"]/) {
        return $1;
    }
    croak "Can't found session_token from response. Url: '$url'";
};

my $getLoginSecurityValue = sub {
    my ($self) = @_;
    my $ua = $self->{ua};
    my $url = 'https://www.mediafire.com/login/';

    my $res = $ua->get($url);
    my $code = $res->code;
    if ($code ne '200') {
        croak "Can't get login_security_value. Code: $code";
    }
    if ($res->decoded_content =~ /<(input [^<>]*name="security".+?)>/) {
        my $tag = $1;
        if ($tag =~ /value="(.+?)"/) {
            return $1;
        }
    }
    croak "Can't find tag with name 'securyty' or can't get value of tag";
};

########################################################################################

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;

    $self->{ua} = LWP::UserAgent->new (
                                    agent           => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.167 Safari/537.36',
                                    cookie_jar      => {},
                                );
    $self->{ua}->default_header('accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8');
    $self->{ua}->default_header('accept-encoding' => 'gzip, deflate, br');
    $self->{ua}->default_header('accept-language' => 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');

    return $self;
}

sub login {
    my ($self, %opt)        = @_;
    $self->{login}          = $opt{-login}          // croak "You must specify '-login' param";
    $self->{password}       = $opt{-password}       // croak "You must specify '-password' param";

    $self->$openMainPage();

    my $security_value = $self->$getLoginSecurityValue();

    my ($res, $code);
    my $ua = $self->{ua};

    my $url = 'https://www.mediafire.com/dynamic/client_login/mediafire.php';

    my %param = (
        security                    => $security_value,
        login_email                 => $self->{login},
        login_pass                  => $self->{password},
        login_remember              => 'on',
    );

    my %headers = (
        'accept-language'           => 'ru,en-US;q=0.9,en;q=0.8',
        'cache-control'             => 'max-age=0',
        'content-type'              => 'application/x-www-form-urlencoded',
        'origin'                    => 'https://www.mediafire.com',
        'referer'                   => 'https://www.mediafire.com/login/',
        'upgrade-insecure-requests' => '1',
    );

    $res = $ua->post($url, \%param, %headers);
    $code = $res->code;
    if ($code ne '200') {
        croak "Wrong response code on login url: '$url'. Code: $code";
    }
    my $cookie = $res->header('set-cookie');
    # If logged in, server set 'session' cookie
    if (not $cookie =~ /session=/) {
        croak "Can't login to mediafire.com";
    }

    $self->renewSessionToken();

    return 1;
}

sub renewSessionToken {
    my ($self) = @_;
    
    if (not $self->{session_token}) {
        $self->{session_token} = $self->$getSessionToken();
        return 1;
    }
    
    my %headers = (
        'referer'                   => 'https://www.mediafire.com/widgets/notifications.php?event_load=1',
        'x-requested-with'          => 'XMLHttpRequest',
    );

    my $url = 'https://www.mediafire.com/api/1.4/user/renew_session_token.php?r=jrko&session_token=' . $self->{session_token} . '&response_format=json'; 
    my $res = $self->{ua}->get($url, %headers);
    my $code = $res->code;
    if ($code ne '200') {
        croak "Can't renew session token by url: '$url'. Code: $code";
    }

    my $json_res = eval {
        decode_json($res->decoded_content);
    };
    if ($@) {
        croak "Can't decode response to json: $res->decoded_content";
    }

    my $response_result = $json_res->{response}->{result};
    if ($response_result eq 'Success') {
        $self->{session_token} = $json_res->{response}->{session_token};
        return 1;
    }
    croak "Wrong result from response for renewSessionToken. Result: $response_result";
}

sub uploadFile {
    my ($self, %opt)            = @_;

    $self->renewSessionToken();
    my $upload_file = Mediafire::Api::UploadFile->new(
        -ua             => $self->{ua},
        -session_token  => $self->{session_token},
    );
    $upload_file->uploadFile(%opt);
    return $upload_file;
}


1;
