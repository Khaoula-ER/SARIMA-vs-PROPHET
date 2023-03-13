/*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Température en Irlande: SARIMA      %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

proc datasets nolist nodetails lib=work kill; /*clean work library */

%let data_dir=/home/u62470273/sasuser.v94/Series temporelles/data; /*initialiser le répertoire des raw data*/
/* macro program 1: pour l'Importation des données csv */
%macro import(name);
	filename file "&data_dir/&data_file1" ;
	proc import out=work.&name. datafile=file dbms=csv replace; 
		getnames=yes;
	run;
%mend;

%let data_file1=mly532.csv; %import(data);

Proc contents data=data; run; *Pour regarder le contenu des données; 

data meant;
  set data (firstobs=1 obs=732);
  format date date9.; 
  date = mdy(11, 1, 1941) + (intck('month', '01NOV1941'd, date)-1)*30; 
  mean = meant;
  drop meant;
run;
/*Notez que j'ai utilisé la fonction mdy() pour spécifier la date de départ (1 novembre 1941),
 et j'ai calculé les dates de chaque observation en ajoutant des multiples de 30 jours (la durée approximative d'un mois)
 à cette date de départ.
*/

proc timeseries data=meant out=meant_ts;
  id date interval=month accumulate=average ;
  var mean;
run;
/*Ensuite, j'ai créé un ensemble de données de séries chronologiques à partir de l'ensemble de données meant en utilisant
 la procédure timeseries. J'ai spécifié la variable de date en utilisant la variable date que j'ai créée précédemment, 
 et j'ai spécifié la variable de données en utilisant la variable mean. J'ai également utilisé l'option accumulate=average
 pour calculer la moyenne des observations à chaque période d'accumulation.*/

/* Trajectoires (regarder la trajectoire de la tepérature aucours du temps)*/
proc sgplot data=meant_ts;
  series x=date y=mean / markers
  markerattrs=(color=blue symbol='asterisk')
                           lineattrs=(color=blue)
                           legendlabel="Série originale" ;
  yaxis values=(0 to 5 by 0.1);
  yaxis label='Température';
run;


/*Pour confirmer la saisonnalité*/

* méthode 1 : avec proc spectra ;
proc spectra data=meant_ts out=spectre_meant_ts p s ;
var mean ;
weight parzen ; /* noyau de parzen */
run;
proc sgplot data=spectre_meant_ts;
series x=period y=s_01 / markers markerattrs=(color=black
symbol=circlefilled);/*circlefilled = pointsnoirs*/
yaxis label='Périodogramme';
run; /* les valeurs de periodigramme en y et les periodes en x*/

/*interprétation: Il y a un pic en 12 : on peut en déduire qu'il y a une période égale à
12*/

proc sgplot data=spectre_meant_ts;
series x=freq y=s_01 / markers markerattrs=(color=black
symbol=circlefilled);
yaxis label='Densité Spectrale';
run;
/* interprétation: un pic clair en pi/6 soit une période de 12*/


* méthode 2 : avec une modèlisation préliminaire: avec proc ARIMA via l'analyse de l'ACF et la PACF ;
/* Estimation du modèle ARIMA  et Tracé de l'ACF et de la PACF avec proc arima */
proc arima data=meant_ts;
  identify var=mean;
  run;
quit;
* interprétation de ACF: Dans ce cas, nous pouvons voir que la corrélation positive la plus forte se produit 
au décalage 12, qui survient après une période de décalages négativement corrélés (4 à 8). Ceci est attendu puisque
 les températures durant cette période seraient nettement différentes de celles du lag 0.
 À cet égard, 12 est le paramètre saisonnier approprié pour le modèle.
* interpretation de PACF: 
nous voyons qu'il y a une forte coupure dans la corrélation au lag 1. Cela implique que la série suit un processus AR(1) 
et la valeur appropriée pour p=1.;
/*La sortie montre clairement un phénomene saisonnier
et une tendance affine en croissance */

* Maintenant on veut améliorer ce modèle ;
/*************************/
/****  Modélisation  ****/
/***********************/

/* 1- On doit différencier  */

proc arima data=meant_ts;
identify var=mean(1,12) stationarity=(adf=6);
run;
quit;
/*Test de Dickey-Fuller augmenté interprétation: serie stationnaire */

proc arima data=meant_ts;
identify var=mean(1,12) stationarity=(pp=6);
run;
quit; 
/* Test de Philips Perron interprétation: serie stationnaire  */
/* On conclue que d=0  et D=1   */

/*** On bascule vers r pour la conclusion sur les étapes suivantes:
/* Choix de p,q, P, Q */
/* Estimation des coefficients */
/*prévisions */
/* évaluation du modèle */
