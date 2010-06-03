#
# url_buffer.pl is written
# by "AYANOKOUZI, Ryuunosuke" <i38w7i3@yahoo.co.jp>
# under GNU General Public License v3.
#
use strict;
use warnings;
use Data::Dumper;
use URI;
use URI::Split qw(uri_split uri_join);

weechat::register("url_buffer", "AYANOKOUZI, Ryuunosuke", "0.1.0", "GPL3", "All URLs in one buffer", "", "");
weechat::hook_signal("*,irc_in_NOTICE", "my_signal_irc_in_NOTICE_cb", "");
weechat::hook_signal("*,irc_in_PRIVMSG", "my_signal_irc_in_PRIVMSG_cb", "");
weechat::hook_signal("*,irc_out_NOTICE", "my_signal_irc_out_NOTICE_cb", "");
weechat::hook_signal("*,irc_out_PRIVMSG", "my_signal_irc_out_PRIVMSG_cb", "");
my $url_buffer = '';
&url_buffer_open("url_buffer");

#black
#default
my @colors = map {weechat::color($_)} qw(
darkgray
red
lightred
green
lightgreen
brown
yellow
blue
lightblue
magenta
lightmagenta
cyan
lightcyan
white
);

sub debug_print
{
	if (0) {
		foreach (@_) {
			weechat::print($url_buffer, $_);
		}
	}
}

sub norm_str
{
	my $str = shift;
	$str =~ s/([^\x00-\x7F]+)/ /g;
	$str =~ s/(\s+)/ /g;
	$str =~ s/\A\s+//g;
	$str =~ s/\s+\Z//g;
	return $str;
}

sub is_valid_rough
{
	my $str = shift;
	my ($scheme, $auth, $path, $query, $frag) = uri_split($str);
	if (defined $scheme && $scheme ne '' &&
			defined $auth && $auth ne '' &&
			defined $path && $path ne '' ) {
		return uri_join($scheme, $auth, $path, $query, $frag);
	} else {
		return undef;
	}
}

sub is_valid
{
	my $str = shift;
	debug_print('str: '.$str);
	if (!&is_valid_rough($str)) {
		debug_print("ERR: rough: ".$@);
		return undef;
	}
	my $uri = URI->new($str);
	if ($@ || !defined $uri) {
		debug_print("ERR: new: ".$@);
		return undef;
	}
	foreach my $method qw(scheme host path port) {
		my $ref_method = eval{$uri->can($method)};
		if ($@ || !defined $ref_method) {
			debug_print("ERR: can: ".Dumper $uri);
			return undef;
		} else {
			my $a = eval{$uri->$ref_method()};
			if ($@ || !defined $a || $a eq '') {
				debug_print("ERR: $method: ".$@);
				return undef;
			} else {
				debug_print("$method: ".$a);
			}
		}
	}

	my $a = eval{$uri->as_string};
	if ($@ || !defined $a || $a eq '') {
		debug_print("ERR: as_string: ".$@);
		return undef;
	} else {
		return $a;
	}
}

sub uri_in_str
{
	my $str = shift;
	debug_print($str);
	$str = &norm_str($str);
	debug_print($str);
	my @url = ();
	foreach (split / /, $str) {
		my $uri = &is_valid($_);
		if (defined $uri) {
			push @url, $uri;
		}
	}
	return @url;
}

sub buffer_get_color
{
	my $server = shift;
	my $channel = shift;
	my $num = 0;
	my $color = 0;
	$num = weechat::info_get("irc_buffer", "$server,$channel");
	$num = weechat::buffer_get_integer($num , "number");
	$color = $colors[$num % $#colors];
	return ($num, $color);
}

sub my_signal_cb
{
	my $data = shift;
	my $server = shift;
	my $signal = shift;
	my $nick = shift;
	my $address = shift;
	my $type = shift;
	my $channel = shift;
	my $msg = shift;

	if (!defined $server || $server eq '' ||
			!defined $channel || $channel eq '') {
		return weechat::WEECHAT_RC_ERROR;
	}

	my ($num, $color) = &buffer_get_color($server, $channel);
#	weechat::print($url_buffer, "$nick\t$msg");
	my @uri = &uri_in_str($msg);
	foreach (@uri) {
		weechat::print($url_buffer, "$color$nick\t$_");
	}
#	if (@uri) {
#		weechat::print($url_buffer, "$color$channel\t$msg");
#	}

	return weechat::WEECHAT_RC_OK;
}

sub my_signal_irc_out_parser
{
	my $data = shift;
	my ($server, $signal) = split /,/, shift, 2;
	my ($head, $msg) = split / :/, shift, 2;
	my ($type, $channel) = split / /, $head, 2;
	my $nick = weechat::info_get("irc_nick", $server);
	my $address = '';
	$nick =~ s/\A://;
	return ($data, $server, $signal, $nick, $address, $type, $channel, $msg, @_);
}

sub my_signal_irc_in_parser
{
	my $data = shift;
	my ($server, $signal) = split /,/, shift, 2;
	my ($head, $msg) = split / :/, shift, 2;
	my ($id, $type, $channel) = split / /, $head, 3;
	my ($nick, $address) = split /!/, $id, 3;
	$nick =~ s/\A://;
	return ($data, $server, $signal, $nick, $address, $type, $channel, $msg, @_);
}


sub my_signal_irc_in_PRIVMSG_cb
{
	return &my_signal_cb(&my_signal_irc_in_parser(@_));
}

sub my_signal_irc_in_NOTICE_cb
{
	return &my_signal_cb(&my_signal_irc_in_parser(@_));
}

sub my_signal_irc_out_PRIVMSG_cb
{
	return &my_signal_cb(&my_signal_irc_out_parser(@_));
}

sub my_signal_irc_out_NOTICE_cb
{
	return &my_signal_cb(&my_signal_irc_out_parser(@_));
}

sub url_buffer_close_cb
{
	$url_buffer = '';
	return weechat::WEECHAT_RC_OK;
}

sub url_buffer_input_cb
{
	return weechat::WEECHAT_RC_OK;
}

sub url_buffer_open
{
	my $url_buffer_name = shift;
	$url_buffer = weechat::buffer_search("perl", $url_buffer_name);

	if ($url_buffer eq '')
	{
		$url_buffer = weechat::buffer_new($url_buffer_name, "url_buffer_input_cb", "", "url_buffer_close_cb", "");
		weechat::print("", "creat buffer named '$url_buffer_name'");
	}
	weechat::buffer_set($url_buffer, "title", "URL buffer");
	return weechat::WEECHAT_RC_OK;
}

