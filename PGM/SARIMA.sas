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
proc means data=data; var date; run;
proc timeseries data=meant out=meant_ts;
  id date interval=month accumulate=average ;
  var mean;
run;

/*Notez que j'ai utilisé la fonction mdy() pour spécifier la date de départ (1 novembre 1941),
 et j'ai calculé les dates de chaque observation en ajoutant des multiples de 30 jours (la durée approximative d'un mois)
 à cette date de départ.

Ensuite, j'ai créé un ensemble de données de séries chronologiques à partir de l'ensemble de données meant en utilisant
 la procédure timeseries. J'ai spécifié la variable de date en utilisant la variable date que j'ai créée précédemment, 
 et j'ai spécifié la variable de données en utilisant la variable mean. J'ai également utilisé l'option accumulate=average
 pour calculer la moyenne des observations à chaque période d'accumulation.*/

/* Trajectoires  */
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
run;
/*Il y a un pic en 12 : on peut en déduire qu'il y a une période égale à
12*/
proc sgplot data=spectre_meant_ts;
series x=freq y=s_01 / markers markerattrs=(color=black
symbol=circlefilled);
yaxis label='Densité Spectrale';
run;/*un pic clair en pi/6 soit une période de 12*/


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
/*Test de Dickey-Fuller augmenté interprétation: */
proc arima data=meant_ts;
identify var=mean(1,12) stationarity=(pp=6);
run;
quit; 
/* Test de Philips Perron interprétation:  */
/* On conclue que d=  et D=   */

/* Choix de p,q, P, Q */
proc arima data=meant_ts;
identify var=mean(1,12) nlag=20 scan  esacf minic ;
run;
quit;
/* (p+d=0, q=1) on teste SARIMA_12(0,1,1)(0,1,1) */
/* On doit prendre q=(1)(12)=(1,12,13)  */

/* Estimation des coefficients */
proc arima data=meant_ts;
identify var=mean(1,12);
estimate q=(1)(12) plot;
run;
quit;
/* Décorrélation des résidus acceptée*/


/*maintenant on va faire des prévisions */
/*pour tester le modèle retenu
SARIMA_12(2,1,0)(1,1,0) */
proc arima data=meant_ts;
identify var=mean (1,12);
estimate p= (1)(12) plot; /*on reprend les parametres du modele */
forecast lead=20 interval=month id=date out=prev;
run;
quit;

/*************************/
/****  Prévisions ****/
/***********************/


/* Vérification du modèle */
data prev_1;
set prev;
debut='01jan2010'd; /*date où on fait démarrer les prev*/
fin='01jan2012'd ; /*date où on fait arreter les prev*/
if date lt debut or date gt fin then do;
forecast=.;
l95=.;
u95=.;
end;
run;
/* Comparaison Modèle-prévision */
proc sgplot data=prev_1;
series x=date y=nombre / markers
markerattrs=(color=black )
lineattrs=(color=black)
legendlabel="Série originale" ;
series x=date y=forecast / markers
markerattrs=(color=red )
lineattrs=(color=red)
legendlabel="Prévision" ;
yaxis label= "Nombre en milliards de voyageurs-km";
run;
/** Le modèle semble convenir */


/* Prévision avec région de confiance */
data prev_2; /* On ne garde que les valeurs de prédiction du futur */
set prev_TGV;
debut='01dec2011'd; /*date où on fait démarrer les prev*/
if date lt debut then do;
forecast=.;
l95=.;
u95=.;
end;
run;
/* Visualisation de la prévision future */
proc sgplot data=prev_2;
series x=date y=nombre / markers
markerattrs=(color=black )
lineattrs=(color=black)
legendlabel="Série originale" ;
series x=date y=forecast / markers
markerattrs=(color=blue )
lineattrs=(color=blue)
legendlabel="Prévision" ;
series x=date y=l95 / markers
markerattrs=(color=green )
lineattrs=(color=green)
legendlabel="borne inf " ;
series x=date y=u95 / markers
markerattrs=(color=red )
lineattrs=(color=red)
legendlabel="borne sup" ;
yaxis label= "Nombre en milliards de voyageurs-km";
run;
s








