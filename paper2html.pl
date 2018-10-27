

use strict;
use warnings;

use Dumpvalue;
use Math::Round;

use utf8;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


my $paperList = [];
my $affCount = {};

my $action;
my $buf;
my $paper;
my $lineno = 0;
while (<STDIN>) {
    $lineno++;
    chomp;
    if (/^$/) {
	$action = "CLEAR";
    } elsif (/^\#/) {
	$action = "NOOP";
    } elsif (/^http/) {
	unless ($action eq "AUTHOR") {
	    die "$lineno\tURL must follow AUTHOR";
	}
	$action = "URL";
	$buf = $_;
    } elsif (/^(LONG|SHORT|STUDENT|DEMO)$/) {
	$action = "TYPE";
	$buf = $_;
    } elsif ($action eq "TYPE") {
	$action = "TITLE";
	$buf = $_;
    } elsif ($action eq "TITLE") {
	$action = "AUTHOR";
	$buf = $_;
    } elsif ($action eq "AUTHOR") {
	$action = "AUTHOR";
	$buf = $_;
    }

    if ($action eq "TYPE") {
	if ($paper) {
	    die "previous paper";
	}
	$paper = { "type" => $buf, "authors" => [] }
    } elsif ($action eq "TITLE") {
	$paper->{"title"} = $buf;
    } elsif ($action eq "AUTHOR") {
	my @tmp = split(/\t/, $buf);
	my $name = shift(@tmp);
	push(@{$paper->{"authors"}}, { "name" => $name, "affiliation" => \@tmp });
    } elsif ($action eq "URL") {
	$paper->{"url"} = $buf;
    } elsif ($action eq "CLEAR") {
	if ($paper) {
	    push(@$paperList, $paper);
	    $paper = undef;
	}
    } elsif ($action eq "NOOP") {
    } else {
	die "unsupported operation";
    }
}

# Dumpvalue->new->dumpValue($paperList);
# exit;

foreach my $paper (@$paperList) {
    my $L = scalar(@{$paper->{"authors"}});
    if ($L <= 0) {
    	die "malformed paper";
    }
    for (my $i = 0; $i < $L; $i++) {
	my $w;
	if ($L == 1) {
	    $w = 1.0;
	} elsif ($i == 0) {
	    $w = 0.5;
	} else {
	    $w = 0.5 / ($L - 1);
	}
	if ($paper->{"type"} eq "SHORT") {
	    $w *= 0.75;
	} elsif ($paper->{"type"} =~ /^(STUDENT|DEMO)$/) {
	    $w *= 0.5;
	}
	my $author = $paper->{authors}->[$i];
	my $J = scalar(@{$author->{"affiliation"}});
	foreach my $aff (@{$author->{"affiliation"}}) {
	    unless ($aff =~ /^\#/) {
		$affCount->{$aff} += $w / $J;		
	    }
	}
    }
}

# Dumpvalue->new->dumpValue($affCount);

my @sorted = sort { $affCount->{$b} <=> $affCount->{$a} or $a cmp $b } keys(%$affCount);
# foreach my $aff (@sorted) {
#     printf("%s\t%.2f\n", $aff, nearest(0.01, $affCount->{$aff}));
# }

printf <<'__DOC_HEADER__';
<div class="container-fluid">
<h1>日本所属の言語処理トップカンファレンス論文 (2018年)</h1>
<div>
<p class="text-right">MURAWAKI Yugo</p>
<p class="text-right">Last Update: October 27, 2018.</p>
</div>

<div>
<p>
日本の組織を所属とする者が、2018年に言語処理のトップカンファレンスもしくはトップ論文誌で発表した論文一覧です (<a href="http://murawaki.org/misc/japan-nlp-2017.html">2017年版</a>。<a href="http://murawaki.org/misc/japan-nlp-2016.html">2016年版</a>。<a href="http://phontron.com/misc/japan-nlp-2015.html">2015年版</a>、<a href="http://phontron.com/misc/japan-nlp-2014.html">2014年版</a>は Graham Neubig さん (NAIST、現 CMU) が作成)。
対象は TACL、NAACL、ACL、COLING、EMNLP です。Student/Demo 論文も含みます。
収集は手作業なので漏れがあるかもしれません。
</p>
方針:
<ul>
<li>full paper 1 本に対して、short paper は 0.75 本、student research workshop/system demonstration は 0.5 本換算。</li>
<li>所属は大学、研究所、企業くらいの単位で近似しています。実際の研究グループはそれよりも小さい単位の方が多いと思いますが、外部から客観的にそれを同定するのは難しいので。</li>
<li>著者が複数の場合は、第1著者に 0.5 を配分し、残りの 0.5 は以降の著者で等分。</li>
<li>1人の著者に複数の所属がある場合は等分。</li>
<li>所属は論文における著者の自己申告に機械的に従います。</li>
</ul>
</div>
__DOC_HEADER__

printf <<'__TABLE_HEADER__';
<div>
<h2>所属ごとの論文数</h2>
<table class="table table-bordered table-striped" style="width: auto;">
<thead>
<tr>
<th>数</th>
<th>所属</th>
</tr>
</thead>
<tbody>
__TABLE_HEADER__

foreach my $aff (@sorted) {
    printf("<tr><td>%.2f</td><td>%s</td></tr>\n", nearest(0.01, $affCount->{$aff}), $aff);
}
printf <<'__TABLE_FOOTER__';
</tbody>
</table>
</div>
__TABLE_FOOTER__

printf <<'__TABLE_HEADER__';
<div>
<h2>論文</h2>
<table class="table table-bordered table-striped">
<thead>
<tr>
<th>種別</th>
<th>著者 (所属)</th>
<th>論文表題</th>
</tr>
</thead>
<tbody>
__TABLE_HEADER__

foreach my $paper (@$paperList) {
    my @authors;
    foreach my $author (@{$paper->{"authors"}}) {
	my @affs;
	for my $aff (@{$author->{affiliation}}) {
	    if ($aff =~ /^\#/) {
		push(@affs, sprintf("<span style=\"color: grey;\">%s</span>", substr($aff, 1)));
	    } else {
		push(@affs, $aff);
	    }
	}
	my $affiliations = join("; ", @affs);
	push(@authors, sprintf("%s (%s)", $author->{name}, $affiliations));
    }
    my $authors = join("<br>", @authors);
    printf("<tr><td style=\"vertical-align: middle;\">%s</td><td>%s</td><td style=\"vertical-align: middle;\"><a href=\"%s\">%s</a></td></tr>\n", $paper->{"type"}, $authors, $paper->{"url"}, $paper->{"title"});
}

printf <<'__TABLE_FOOTER__';
</tbody>
</table>
</div>
__TABLE_FOOTER__

printf <<'__DOC_FOOTER__';
</div>
__DOC_FOOTER__

1;
