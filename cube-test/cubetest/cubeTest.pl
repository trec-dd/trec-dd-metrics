## CubeTest Implementation For TREC Dynamic Domain Track Evaluation

## For Linux Unix Platform

## Copyright by InfoSense Group, Georgetown University

## Version: lgc

## Date: 12/03/2014

#########################################

#!/usr/bin/perl -w

#########################################

#### Parameter setup and initialization

$MAX_JUDGMENT = 4; # Maximum gain value allowed in qrels file.

$beta =1; #a factor decide recall-oritention or precision-oritention

$gamma = 0.5;

$QRELS = $ARGV[0];
$RUN = $ARGV[1];
$gamma = $ARGV[2];
$K = $ARGV[3]; 

# $topic $docno $subtopic $judgement
%qrels=();
#$topic $subtopic $area
%subtopicWeight=();
# $topic $subtopic $gainHeights
%currentGainHeight=();
# $topic $subtopic $ocurrences
%subtopicCover = ();
# $docID $docLength
%docLengthMap = ();
%seen=();

#########################################

#### Read qrels file(groundtruth), check format, and sort

open (QRELS, $QRELS) || die "$0: cannot open \"$QRELS\": !$\n";
while (<QRELS>) {
  s/[\r\n]//g;
  ($topic, $subtopic, $docno, $judgment, $subTWeigt) = split ('\s+');
  $topic =~ s/^.*\-//;
  die "$0: format error on line $. of \"$QRELS\"\n"
    unless
      $topic =~ /^[0-9]+$/ 
      && $judgment =~ /^-?[0-9]+$/ && $judgment <= $MAX_JUDGMENT;
  if ($judgment > 0) {
    $qrels{$topic}{$docno}{$subtopic}=$judgment/$MAX_JUDGMENT;
    if(!exists $subtopicWeight{$topic}{$subtopic}){
      if(defined $subTWeigt && length $subTWeigt> 0){
         $subtopicWeight{$topic}{$subtopic} = $subTWeigt;
      }      
      $currentGainHeight{$topic}{$subtopic} = 0;
      $subtopicCover{$topic}{$subtopic} = 0;
    }

    $seen{$topic}++;
  }
}
close (QRELS);

#########################################

#### Normalize subtopic weight

for my $tkey (keys %subtopicWeight){
    my %subs = %{$subtopicWeight{$tkey}};
    my $maxWeight = &getMaxWeight($tkey);
    for my $skey (keys %subs){        
        $subtopicWeight{$tkey}{$skey} = $subtopicWeight{$tkey}{$skey}/$maxWeight;
    }
}

sub getMaxWeight{
  my ($topic) = @_;
  my $maxWeight = 0;
  my %subtopics = %{$subtopicWeight{$topic}};
  for my $skey (keys %subtopics){
      $maxWeight += $subtopics{$skey};
  }
  return $maxWeight;
}

$topics = 0;
$runid = "?????";

#########################################

#### Read run file(returned document rank lists), check format, and sort

open (RUN, $RUN) || die "$0: cannot open \"$RUN\": !$\n";
my $rank = "";
while (<RUN>) {
  s/[\r\n]//g;
  ($topic, $q0, $docno, $rank, $score, $runid, $doclength) = split ('\s+');
  $topic =~ s/^.*\-//;
  die "$0: format error on line $. of \"$RUN\"\n"
    unless
      $topic =~ /^[0-9]+$/ && $q0 eq "Q0" && $docno;
  $run[$#run + 1] = "$topic $docno $score";

  if(defined $doclength && length $doclength > 0){
     if(!exists $docLengthMap{$docno}){
     	$docLengthMap{$docno} = $doclength;
     }
  } 
}

#########################################

#### Process runs: compute measures for each topic and average

print "runid,topic,ct_speed\@$K,ct_accel\@$K\n";
$topicCurrent = -1;
for ($i = 0; $i <= $#run; $i++) {
  ($topic, $docno, $score) = split (' ', $run[$i]);
  if ($topic != $topicCurrent) {
    if ($topicCurrent >= 0) {
      &topicDone ($RUN, $topicCurrent, @docls);
      $#docls = -1;
    }
    $topicCurrent = $topic;
  }
  $docls[$#docls + 1] = $docno;
}
if ($topicCurrent >= 0) {  
  &topicDone ($RUN, $topicCurrent, @docls);
  $#docls = -1;
}
if ($topics > 0) {
  $ndcgAvg = $ndcgTotal/$topics;
  $accelAvg = $ct_accuTotal/$topics;

  printf "$RUN,amean,%.10f,%.10f\n",$ndcgAvg,$accelAvg;
} else {
  print "$RUN,amean,0.00000,0.00000\n";
}

exit 0;

#########################################

#### Compute and report information for current topic

sub topicDone {
  my ($runid, $topic, @docls) = @_;
  my($ndcg) = (0);
  if (exists $seen{$topic}) {
    my $_ct = &ct($K, $topic, @docls);
    my $_time = &getTime($K, $topic, @docls);

    my $ct_accu = 0;
    my $limit = ($K <= $#docls? $K : $#docls + 1);
    for($count =0 ; $count < $limit; $count ++){
        &clearEnv;
        my $accel_ct = &ct($count + 1, $topic, @docls);
        my $accel_time = &getTime($count + 1, $topic, @docls);

        $ct_accu += $accel_ct / $accel_time;
    }
    $ct_accu = $ct_accu / $limit;
    $ct_accuTotal += $ct_accu;
    
    my $ct_speed = $_ct / $_time;
    $ndcgTotal += $ct_speed;
    $topics++;
    printf  "$runid,$topicCurrent,%.10f,%.10f\n",$ct_speed,$ct_accu;
  }
}

sub clearEnv{
  for my $tkey (keys %currentGainHeight){
      my %subs = %{$currentGainHeight{$tkey}};
      for my $skey (keys %subs){
          $currentGainHeight{$tkey}{$skey}=0;
      }
  }

  for my $tkey (keys %subtopicCover){
      my %subs = %{$subtopicCover{$tkey}};
      for my $skey (keys %subs){
          $subtopicCover{$tkey}{$skey}=0;
      }
  }  
}

#########################################

#### Compute ct over a sorted array of gain values, reporting at depth $k

sub ct {
 my ($k, $topic, @docls) = @_;
 my ($i, $score) = (0, 0);
 for ($i = 0; $i <= ($k <= $#docls ? $k - 1 : $#docls); $i++) {
   my $docGain = &getDocGain($topic, $docls[$i], $i + 1);
   $score += $docGain;
 }
 return $score;
}

sub getDocGain{
  my ($topic, $docno, $rank) = @_;
  my $rel = 0;
  
  if(exists $qrels{$topic}{$docno}){
    my %subtopics = %{$qrels{$topic}{$docno}};
    my $inFlag = -1;
    for my $subKey(keys %subtopics){
        if(&isStop($topic, $subKey) < 0 ){
           my $boost = 1;
           for my $subKey1(keys %subtopics){
               if(exists $currentGainHeight{$topic}{$subKey1} && $subKey != $subKey1){
                  my $areaW = &getArea($topic, $subKey1);
                  my $heightW =  $currentGainHeight{$topic}{$subKey1};
                  $boost += $beta * $areaW * $heightW;
               }               
           }

           my $pos = 0;
           if(exists $subtopicCover{$topic}{$subKey}){
              $pos = $subtopicCover{$topic}{$subKey};
           }

           my $height = &getHeight($topic, $docno, $subKey,$pos + 1, $boost);

           my $area = &getArea($topic, $subKey);

           $rel = $beta * $area * $height;
        }
    }

    for my $subKey (keys %subtopics){
           $subtopicCover{$topic}{$subKey}++;
    }
    
  }

  return $rel;   
}

#########################################

#### Get subtopic importance

sub getArea{
  my ($topic, $subtopic) = @_;
  
  if(exists $subtopicWeight{$topic}{$subtopic}){
     return $subtopicWeight{$topic}{$subtopic};
  }else{
     $subtopicWeight{$topic}{$subtopic} = &getDiscount($subtopic)/&getMaxArea($topic);
     return $subtopicWeight{$topic}{$subtopic};
  }

  return 0;
}

sub getHeight{
  my ($topic, $docno, $subtopic, $pos, $benefit) = @_;
  
  #set $benefit = 1 if don't want to consider boost effect
  #$benefit = 1;
  my $rel = &getHeightDiscount($pos) * $qrels{$topic}{$docno}{$subtopic} * $benefit;

  $currentGainHeight{$topic}{$subtopic} += $rel;

  return $rel;
}

sub getHeightDiscount{
  my ($pos) = @_;

  return ($gamma) ** $pos;
}


sub isStop{
  my ($topic, $subtopic) = @_;
  if($currentGainHeight{$topic}{$subtopic} < 1){
    return -1;
  }

  return 0;
}

sub getTime{
  my ($pos, $topic, @docls) = @_;

  my $time =0;
  for (my $count = 0; $count < $pos && $count <= $#docls ; $count++) {
       my $prob = 0.39;
       if (exists $qrels{$topic}{$docls[$count]}){
         $prob = 0.64;
       }

 	$time += 4.4 + (0.018*$docLengthMap{$docls[$count]} +7.8)*$prob;
  }

  return $time;
}

sub getDiscount{
  my ($pos) = @_;

  return 1/(log($pos + 1)/log(2));
}

sub getMaxArea{
  my ($topic) = @_;

  my %subtopics = %{$subtopicCover{$topic}};
  my @subs = keys %subtopics;
  my $subtopicNum = $#subs + 1;

  my $maxArea = 0;
  for($count = 0;$count < $subtopicNum; $count++){
     $maxArea += &getDiscount($count + 1);
  }

  return $maxArea;
}
