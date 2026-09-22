FILENAME REFFILE '/home/u64508045/The Data/Car_details (2).csv';

PROC IMPORT DATAFILE=REFFILE
    DBMS=CSV
    OUT=WORK.IMPORT
    REPLACE;
    GETNAMES=YES;
RUN;

/* Part 1: Exploration */
proc contents data=WORK.IMPORT;
run;

proc print data=WORK.IMPORT(obs=10);
run;

proc means data=WORK.IMPORT n mean std min max;
    var selling_price km_driven seats year;
run;

proc freq data=WORK.IMPORT;
    tables fuel seller_type transmission owner;
run;

proc gchart data=WORK.IMPORT;
    pie owner/ type=percent;
    title "Distribution of Vehicles by type of owners";
run;

proc gchart data=WORK.IMPORT;
    pie fuel / type=percent;
    title "Distribution of Vehicles by Fuel Type";
run;
proc gchart data=WORK.IMPORT;
    pie seller_type / type=percent;
    title "Distribution of Vehicles by Seller Type";
run;
proc gchart data=WORK.IMPORT;
    pie transmission/ type=percent;
    title "Distribution of Vehicles by transmission";
run;
proc sgplot data=WORK.IMPORT;
    histogram selling_price;
    density selling_price;
run;

proc sgplot data=WORK.IMPORT;
    vbox selling_price / category=transmission;
    title "Price by Transmission";
run;
proc sgplot data=WORK.IMPORT;
    scatter x=km_driven y=selling_price;
run;
proc sort data=WORK.IMPORT out=sorted_desc;
    by descending selling_price;
run;
proc print data=sorted_desc(obs=10);
    title "Top 10 Most Expensive Cars";
run;

proc sort data=WORK.IMPORT out=sorted_asc;
    by selling_price;
run;

proc print data=sorted_asc(obs=10);
    title "Top 10 Cheapest Cars";
run;
data cars_clean_step1;
    set WORK.IMPORT;

    mileage_num   = input(scan(mileage,1,' '), best12.);
    engine_num    = input(scan(engine,1,' '), best12.);
    max_power_num = input(scan(max_power,1,' '), best12.);
    
    _std_torque = tranwrd(torque, ' at ', '@');
    torque_value = input(compress(scan(_std_torque, 1, '@'),'.', 'dk'), ?? best12.);
    
    if find(torque, 'kgm', 'i') > 0 then 
    	torque_value = torque_value * 9.8;
    
    _rpm_string    = scan(_std_torque, 2, '@');
    torque_rpm_min = input(compress(scan(_rpm_string, 1, '-'), '.', 'dk'), ?? best12.);
    torque_rpm_max = input(compress(scan(_rpm_string, 2, '-'),'.', 'dk'), ?? best12.);
    
    if missing(torque_rpm_max) and not missing(torque_rpm_min) then 
        torque_rpm_max = torque_rpm_min;
        
    torque_rpm = mean(torque_rpm_min, torque_rpm_max);
    
    drop _rpm_string torque_rpm_max torque_rpm_min _std_torque mileage engine max_power torque;
run;

ods graphics / width=10in height=5in;
ods layout gridded columns=2;
ods region;
proc sgplot data=WORK.IMPORT (obs=100); 
    vbar max_power / fillattrs=(color=gray);
    title "BEFORE: Engine Power as Text Strings";
    xaxis label="Unordered Text Categories ('85 bhp', '100 bhp', etc.)" display=(novalues);
    yaxis label="Frequency";
run;

ods region;
proc sgplot data=cars_clean_step1;
    scatter x=max_power_num y=selling_price / markerattrs=(color=purple size=3) transparency=0.6;
    reg x=max_power_num y=selling_price / lineattrs=(color=black thickness=2);
    title "AFTER: Extracted Numeric Power";
    xaxis label="Max Power (Numeric)";
    yaxis label="Selling Price";
run;

ods layout end;
ods graphics / reset;


proc contents data=cars_clean_step1;
    title "After Conversion";
run;

proc corr data=cars_clean_step1;
    var selling_price km_driven seats year 
        mileage_num engine_num max_power_num torque_value torque_rpm;
    title "Correlation Matrix";
run;
/* Part 2: Data Cleaning */
proc sort data=cars_clean_step1 nodupkey;
    by name year selling_price km_driven selling_price;
run;

proc surveyselect data=cars_clean_step1 out=cars_split
    samprate=0.80 
    method=srs 
    outall 
    seed=42; 
run;

data cars_train cars_test;
    set cars_split;
    if selected = 1 then output cars_train;
    else output cars_test;
    drop selected; 
run;

proc stdize data=cars_train reponly method=median 
            out=cars_train_imputed 
            outstat=train_medians; 
    var mileage_num max_power_num torque_value torque_rpm engine_num;
run;

proc stdize data=cars_test reponly 
            method=in(train_medians) 
            out=cars_test_imputed;
    var mileage_num max_power_num torque_value torque_rpm engine_num;
run;
proc univariate data=cars_train_imputed noprint;
    var seats;
    output out=mode_temp_ds mode=mode_seats; 
run;

data _null_;
    set mode_temp_ds;
    call symputx('mode_seats', mode_seats);
run;

data cars_train_imputed;
    set cars_train_imputed;
    if missing(seats) then seats = &mode_seats.;
run;

data cars_test_imputed;
    set cars_test_imputed;
    if missing(seats) then seats = &mode_seats.;
run;

%macro check_nulls(input_data);
    proc format;
        value $misschar ' ' = 'Missing' other = 'Populated';
        value missnum     . = 'Missing' other = 'Populated';
    run;

    proc freq data=&input_data.;
        tables _all_ / missing nocum;
        format _character_ $misschar. _numeric_ missnum.;
    run;
    title; 
%mend;
%check_nulls(cars_train_imputed);
%check_nulls(cars_test_imputed);

data cars_combined;
    length split_flag $5;
    set cars_train_imputed(in=in_train) 
        cars_test_imputed(in=in_test);
        
    if in_train then split_flag = 'TRAIN';
    else if in_test then split_flag = 'TEST';
run;

proc transreg data=cars_combined design;
    model class(fuel seller_type transmission) / noint;
    id _all_;
    output out=cars_encoded_combined(drop=_: fuel seller_type transmission name Intercept); 
run;


data cars_train_encoded cars_test_encoded;
    set cars_encoded_combined;
    
    if split_flag = 'TRAIN' then output cars_train_encoded;
    else if split_flag = 'TEST' then output cars_test_encoded;
    
    drop split_flag; 
run;

proc format;
    invalue encode_owner (upcase)
        'TEST DRIVE C' = 0
        'FIRST OWNER'  = 1
        'SECOND OWNER' = 2
        'THIRD OWNER'  = 3
        'FOURTH & ABO' = 4
        other          = . ;
run;

data cars_train_encoded;
    set cars_train_encoded; 
    
    owner_encoded = input(owner, encode_owner.);

    drop owner;
run;

data cars_test_encoded;
    set cars_test_encoded; 
    
    owner_encoded = input(owner, encode_owner.);
    drop owner;
run;

proc univariate data=cars_train_encoded noprint;
    var selling_price;
    output out=price_pctls pctlpts=20 80 pctlpre=P_;
run;

data _null_;
    set price_pctls;
    call symputx('cheap_cutoff', P_20);
    call symputx('expensive_cutoff', P_80);
run;

data cars_train_featured;
    set cars_train_encoded; 

    length price_category $10;
    if selling_price <= &cheap_cutoff. then price_category = "Cheap";
    else if selling_price >= &expensive_cutoff. then price_category = "Expensive";
    else price_category = "Average";

    car_age = 2026 - year;
    km_per_year = km_driven / max(1, car_age);
    power_to_engine_ratio = max_power_num / engine_num;

    if owner_encoded = 1 then is_first_owner = 1;
    else is_first_owner = 0;
run;

data cars_test_featured;
    set cars_test_encoded; 

    length price_category $10;
    if selling_price <= &cheap_cutoff. then price_category = "Cheap";
    else if selling_price >= &expensive_cutoff. then price_category = "Expensive";
    else price_category = "Average";

    car_age = 2026 - year;
    km_per_year = km_driven / max(1, car_age);
    power_to_engine_ratio = max_power_num / engine_num;

    if owner_encoded = 1 then is_first_owner = 1;
    else is_first_owner = 0;
run;

proc means data=cars_train_featured n mean std min max;
    var selling_price km_driven year seats mileage_num engine_num max_power_num
        torque_value torque_rpm owner_encoded car_age km_per_year
        power_to_engine_ratio is_first_owner;
    title "Training Data: Summary Statistics";
run;

proc freq data=cars_train_featured;
    tables price_category;
    title "Training Data: Price Category Distribution";
run;

proc sgplot data=cars_train_featured;
    vbar price_category / response=selling_price stat=mean
        fillattrs=(color=steelblue) ;
    title "Training Data: Average Selling Price by Price Category";
    xaxis label="Price Category";
    yaxis label="Average Selling Price";
run;

proc sgplot data=cars_train_featured;
    scatter x=km_per_year y=selling_price;
    title "Training Data: KM Per Year vs Selling Price";
    xaxis label="Average KM Driven Per Year";
    yaxis label="Selling Price";
run;

title;

proc format;
    invalue encode_cate 
        'Cheap'   = 0
        'Average' = 1
        other     = 2 ;
run;

data cars_train_featured;
    set cars_train_featured;
    price_category_encoded = input(price_category, encode_cate.);
    drop price_category;
run;

data cars_test_featured;
    set cars_test_featured;
    price_category_encoded = input(price_category, encode_cate.);
    drop price_category;
run;

proc stdize data=cars_train_featured method=std 
            out=cars_train_scaled 
            outstat=train_scales; 
    var year km_driven seats mileage_num engine_num max_power_num torque_value torque_rpm 
        owner_encoded  car_age km_per_year;
run;

proc stdize data=cars_test_featured 
            method=in(train_scales) 
            out=cars_test_scaled;
    var year km_driven seats mileage_num engine_num max_power_num torque_value torque_rpm 
        owner_encoded  car_age km_per_year;
run;

ods graphics / width=10in height=5in;
ods layout gridded columns=2;
ods region;
proc sgplot data=cars_train;
    histogram km_driven / fillattrs=(color=orange);
    title "BEFORE: Raw Mileage (Scale: 0 to 300,000+)";
    xaxis label="Raw Kilometers Driven";
run;

ods region;
proc sgplot data=cars_train_scaled; /* Assuming you used PROC STDIZE */
    histogram km_driven / fillattrs=(color=teal);
    title "AFTER: Standardized Mileage (Scale: -3 to +3)";
    xaxis label="Z-Score (Standard Deviations)";
run;

ods layout end;
ods graphics / reset;

ods graphics / width=10in height=5in;
ods layout gridded columns=2;

ods region;
proc sgplot data=cars_train; 
    vbar transmission / fillattrs=(color=orange) datalabel;
    title "BEFORE";
    xaxis label="Transmission Type";
    yaxis label="Number of Cars";
run;
ods region;
proc sgplot data=cars_train_scaled; 
    vbar transmissionAutoma / fillattrs=(color=purple) datalabel;
    title "AFTER: (One-Hot Encoded)";
    xaxis label="transmissionAutoma Feature (1=Yes, 0=No)";
    yaxis label="Number of Cars";
run;
title;
ods layout end;
ods graphics / reset;

proc corr data=cars_train_scaled;
    var _all_;
run;

proc export data=cars_train_scaled
    outfile='/home/u64508045/cleaning/Train_Car_Details.csv'
    dbms=csv
    replace;
run;

proc export data=cars_test_scaled
    outfile='/home/u64508045/cleaning/Test_Car_Details.csv'
    dbms=csv
    replace;
run;
ods graphics / width=8in height=6in;
proc sgscatter data=cars_train_scaled; 
    plot selling_price * (car_age km_per_year max_power_num engine_num mileage_num torque_value) 
         / columns=2 rows=3 grid markerattrs=(symbol=CircleFilled size=5); 
run;
ods graphics / reset;
proc reg data=cars_train_scaled outest=model_baseline plots=none;

    model selling_price = fuelCNG fuelDiesel fuelLPG seller_typeDealer
    						seller_typeindividual transmissionAutoma  km_driven seats
    						mileage_num engine_num max_power_num torque_value torque_rpm owner_encoded car_age
    						km_per_year power_to_engine_ratio  ;
run;

proc glmselect data=cars_train_scaled outdesign=lasso_features;
    model selling_price = fuelCNG fuelDiesel fuelLPG seller_typeDealer
    						seller_typeindividual transmissionAutoma  km_driven seats
    						mileage_num engine_num max_power_num torque_value torque_rpm owner_encoded car_age
    						km_per_year power_to_engine_ratio  
                          / selection=lasso(choose=cv stop=none);
    score data=cars_test_scaled out=cars_test_scored predicted=Lasso_Pred;
run;

proc glmselect data=cars_train_scaled plots=none;
    
    effect poly_features = polynomial(fuelCNG fuelDiesel fuelLPG seller_typeDealer
    						seller_typeindividual transmissionAutoma  km_driven seats
    						mileage_num engine_num max_power_num torque_value torque_rpm owner_encoded car_age
    						km_per_year power_to_engine_ratio 
                                      / degree=2);
    
    model selling_price = fuelCNG fuelDiesel fuelLPG seller_typeDealer
    						seller_typeindividual transmissionAutoma km_driven seats
    						mileage_num engine_num max_power_num torque_value torque_rpm owner_encoded car_age
    						km_per_year power_to_engine_ratio poly_features 
                              / selection=lasso(choose=cv stop=none) 
                                stats=all;
    
    score data=cars_test_scaled out=cars_test_scored_poly predicted=Pred_Price;
    

run;

proc logistic data=cars_train_scaled;
    class price_category_encoded (ref='0') / param=ref;
    
    model price_category_encoded = fuelCNG fuelDiesel fuelLPG seller_typeDealer
    						seller_typeindividual transmissionAutoma km_driven seats
    						mileage_num engine_num max_power_num torque_value torque_rpm owner_encoded car_age
    						km_per_year power_to_engine_ratio 
                                   / link=glogit;
                       
    score data=cars_test_scaled out=logistic_preds;
run;

proc freq data=logistic_preds;
  
    tables F_price_category_encoded * I_price_category_encoded 
           / crosslist out=matrix_stats; 
run;

proc freq data=logistic_preds;
    tables F_price_category_encoded * I_price_category_encoded / 
           norow nopercent nocol; 
run;

data accuracy_calc;
    set logistic_preds;
    if F_price_category_encoded = I_price_category_encoded then correct = 1;
    else correct = 0;
run;


proc means data=accuracy_calc mean;
    var correct;
    title "Overall Model Accuracy (Percentage Correct)";
run;


