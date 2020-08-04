use IRC::Client;
#my $irc = IRC::Async.new(host => $ircserver, password => $ircpass, nick => $ircuser, userreal => "https://github.com/moon-chilled/SEProxy", channels => [$ircchan]);

my ($seuser, $semail, $sepass, $ircuser, $ircpass) = 'auth.txt'.IO.lines;
my ($seroom, $ircserver, $ircchan) = 'conn.txt'.IO.lines;
my $safeaplsrc = slurp 'safe.apl';
my $py = Proc::Async.new('python3', 'support.py', :w);
my $irc;

sub aplev($src) {
        my $apl = run 'mapl', :in, :out, :err;

        $apl.in.say: $safeaplsrc;
        $apl.in.say: "Safe.Exec '{S:g/\'/\'\'/ given $src}'\n";
        $apl.in.close;
        $apl.err.close;
        my @ret = $apl.out.lines;
        $apl.out.close;
        return @ret;
}
sub paste(@lines) {
	my $proc = run 'curl', '-s', '-F', 'file=@-;filename=t.txt', 'https://0x0.st/', :in, :out;
	for @lines { $proc.in.say($_) }
	$proc.in.close;
	my $ret = slurp $proc.out;
	$proc.out.close;
	return $ret;
}
sub handle-eval($src) { Thread.start({
	my @lines = aplev $src;

	#arbitrary
	if @lines > 9 {
		my $u = paste(@lines);
		$py.write("$u\n".encode);
		$irc.send: :where($ircchan), :text($u);
		return
	}

	for @lines { $irc.send: :where($ircchan), :text($_); }
	$py.write((@lines.map('    ' ~ *.subst('\\', '\\\\')).join('\\n')~"\n").encode)
}) }

class SEProxy does IRC::Client::Plugin {
	method irc-connected($) { $irc.send: :where($ircchan), :text<I am APLBot!>;
	start react {
		whenever $py.stdout.lines {
			my ($id,$user) = $_.split('|')[0..1];
			my $msg = $_.split('|')[2..*].join('|').subst('\n', "\n", :g);
			say "(SE) ($id) <$user> $msg"; #todo: $id is wrong, for some reason
			next if $user.lc eq $seuser.lc;
			my $sseuser = $seuser.subst(/\s/, '', :g);
			handle-eval((S:i/^'⋄'|('@'$sseuser)// given $msg)) if $msg.lc.starts-with('⋄'|"@$sseuser".lc);
			$irc.send: :where($ircchan), :text("<$user> $msg") unless $user.lc eq $seuser.lc;
		}
		whenever $py.stderr.lines { .say }
		whenever $py.start {
			say "Chatexchange subprocess died; bailing";
			done;
		}
		whenever $py.ready {
			say "starting";
			$py.write("$semail\n$sepass\n$seroom\n\n".encode);
		}
		whenever signal(SIGTERM).merge: signal(SIGINT) {
			done;
		}

		whenever Supply.from-list($*IN.lines, scheduler => $*SCHEDULER) {
			$irc.quit if $_ ~~ /quit/;
			#$py.write(($_ ~ "\n").encode);
		}
	}}
	method irc-privmsg-channel($e) {
		say "(IRC) <$e.nick()> $e.text()";
		$py.write((S:g/\\/\\\\/ given "<$e.nick()> $e.text()\n").encode);
		handle-eval((S:i/^'⋄'|($ircuser ':')// given $e.text)) if $e.text.lc.starts-with('⋄'|"$ircuser:".lc);
		Nil;
	}
}

$irc = IRC::Client.new:
	:nick($ircuser)
	:password($ircpass)
	:userreal<https://github.com/moon-chilled/SEProxy>
	:host($ircserver)
	:channels($ircchan)
	:port(6697)
	:ssl(True)
	:plugins(SEProxy);
$irc.run;

$py.kill: SIGINT;

say 'biya!';
