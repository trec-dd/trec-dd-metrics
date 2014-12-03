## CubeTest Implementation For TREC Dynamic Domain Track Evaluation

## For Linux Unix Platform

## Copyright by InfoSense Group, Georgetown University

## Version: lgc

## Date: 12/03/2014

$usage = "Usage: perl evalRunCT.pl qrel inputDir cutoff target\n";

$arg = 0;
$qrel = $ARGV[$arg++] or die $usage;
$path = $ARGV[$arg++] or die $usage;
$K = $ARGV[$arg++] or die $usage;
$target = $ARGV[$arg++] or die $usage;
$gamma  = 0.5;

`mkdir $target`;
`mkdir $target/Detail`;
`mkdir $target/Total`;

foreach $i (`ls -1 $path`){
   if($i =~ /(.*?)\s/){
      `perl cubeTest\.pl $qrel $path/$1 $gamma $K > tmp`;
      open(IN,"tmp"); 

$result = <IN>;
while($result){
  if($result =~ /^(\S+?),(\S+?),(\S+?),(\S+)/){
    if($2 eq "topic"){
       $result = <IN>;
       next;
    }

    if($2 eq "amean"){
       `echo "$result" >> $target/Total/eval_all.txt`;

       $result = <IN>;
       next;
    }
   
    if($2 ne "amean"){
       `echo "$2 $4" >> $target/Detail/$i`;
    }
  }
  
  $result = <IN>;
}

close(IN);
   }
}