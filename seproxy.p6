use IRC::Client;
use HTML::Entity;
use File::Temp;
#my $irc = IRC::Async.new(host => $ircserver, password => $ircpass, nick => $ircuser, userreal => "https://github.com/moon-chilled/SEProxy", channels => [$ircchan]);

my ($seuser, $semail, $sepass, $ircuser, $ircpass) = 'auth.txt'.IO.lines;
my ($seroom, $ircserver, $ircchan) = 'conn.txt'.IO.lines;
#my $safeaplsrc = slurp 'safe.apl';
#my $safeaplsrc = (slurp 'dyalog-safe-exec/Safe.dyalog') ~ (slurp 'safe-helper.apl');
my $safeaplsrc = slurp 'safe-helper.apl';
my $py = Proc::Async.new('python3', 'support.py', :w);
my $irc;
%*ENV<DYALOG_LINEEDITOR_MODE> = 1;

sub aplev($src) {
	my @src = [''];
	my $nesting = 0;
	my $quoting = False;
	grammar Blub {
		token TOP { <c>* }
		token c {
			| (\n|'⋄') {	if $nesting || $quoting { @src[*-1] ~= '⋄' }
					else { @src.append: '' } }
			| '{' { $nesting++ unless $quoting; @src[*-1] ~= '{' }
			| '}' { $nesting-- unless $quoting; @src[*-1] ~= '}' }
			| "'" { $quoting = !$quoting; @src[*-1] ~= "'" }
			#| "''" { @src[*-1] ~= "''" }
			| (<-[\n⋄]>) { @src[*-1] ~= $0 }
		}
	}
	Blub.parse((S:g/"'"/''/ given $src));

	my ($fn,$fh) = tempfile(:suffix<.apln>);
        my $apl = run 'dyalog', '-script', '/dev/stdin', :in, :out, :err; # -x: quiet when loading ws

        $apl.in.say: $safeaplsrc;
        $apl.in.say: "tmp←n f '$_'\n" for @src;
        $apl.in.close;
        $apl.err.close;
	.say for $apl.err.lines;
        my @ret = $apl.out.lines;
        $apl.out.close;
	.say for @ret;
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
sub handle-eval($src is copy, $id, $nick) { Thread.start({
	if $src.starts-with('`') { $src = $src.substr(1, *); }
	if $src.ends-with('`') { $src = $src.substr(0, *-1); }

	my @lines = aplev $src;
	while @lines>1 && !@lines[0].trim { @lines = @lines[1 .. *]; }

	@lines = ['(no output)'] unless @lines;

	#arbitrary
	if @lines > 16 {
		my $u = [paste(@lines)];
		if $id { $py.write(":$id $u\n".encode); }
		else { $py.write("$u".encode); }
		$irc.send: :where($ircchan), :text("$nick: $u");
	} else {
		if @lines == 1 && @lines[0].starts-with("(MAGIC)") {
			if $id { $py.write(":$id\\n".encode) }
			$py.write((@lines[0].subst('(MAGIC)', '') ~ "\n").encode);
			$irc.send: :where($ircchan), :text("$nick: {@lines[0].subst('(MAGIC)', '')}");
		} elsif @lines == 1 {
			if $id { $py.write(":$id\\n".encode) }
			$py.write(('`' ~ @lines[0].trim.subst('\\', '\\\\') ~ "`\n").encode);
			$irc.send: :where($ircchan), :text("$nick: @lines[0]");
		} else {
			if $id { $py.write("    @$nick\\n".encode) }
			$py.write((@lines.map({"    $_".subst('(MAGIC)', '')}).join("\\n") ~ "\n").encode);
			#$irc.send: :where($ircchan), :text("$nick:");
			for @lines { $irc.send: :where($ircchan), :text($_.subst('(MAGIC)', '')); }
		}
	}
})
}

sub html-niceify($text) {
	S:g/'<' <-[<>]>* '>'// given
	(S:g/'<i>'|'</i>'/_/ given
	(S:g/'<b>'|'</b>'/*/ given
	(S:g/'<br>'/\n/ given $text)))
}

sub handle-semsg($line) {
	my ($id,$user) = $line.split('|')[0..1];
	my $sseuser = $seuser.subst(/\s/, '', :g);
	my $msg = $line.split('|')[2..*].join('|').subst('\n', "\n", :g);
	next unless $msg && $id && $user;
	say "(SE) ($id) <$user> $msg";
	next if $user.lc eq $seuser.lc;
	my $nmsg = html-niceify $msg.trim;
	say "(SE) ($id) <$user> {$nmsg.lines[0]}";
	$irc.send: :where($ircchan), :text("<$user> {$nmsg.lines[0]}");
	$irc.send: :where($ircchan), :text("$_") for $nmsg.lines[1..*];

	my $ev = $msg.lc.starts-with('⋄')
	|| $msg.starts-with("    ⋄")
	|| (($msg.lc ~~ /'<pre' .* '>⋄'/) && $msg.lc.ends-with('</pre>'));
	if $msg.lc ~~ /'<code>' \s* '⋄'/ {
		$ev = True;
		$msg = ($msg ~~ m:g/'<code>' \s* '⋄' (.+?) '</code>'/).map(~*[0]).join('⋄');
	}
	$msg = html-niceify $msg.trim;
	handle-eval((S:i/^'⋄'|('@'$sseuser)// given $msg), $id, $user) if $ev;
}

class SEProxy does IRC::Client::Plugin {
	method irc-connected($) { #$irc.send: :where($ircchan), :text<I am APLBot!>;
	start react {
		whenever $py.stdout.lines {
			handle-semsg $_
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
		handle-eval((S:i/^'⋄'|($ircuser ':')// given $e.text),0,$e.nick()) if $e.text.lc.starts-with('⋄'|"$ircuser:".lc);
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
