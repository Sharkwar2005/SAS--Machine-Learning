# Used Car Pricing Intelligence & Predictive Modeling

## ✦ Project Overview
This project focuses on extracting business intelligence from a dataset of over 8,000 used car listings in the Indian market. The objective is to replace guesswork in vehicle pricing with data-driven predictive models that determine fair selling prices, identify the primary factors driving car value, and resolve significant data quality gaps.

## ✦ Problem Statement
The dealership's intake team currently estimates vehicle prices intuitively based on the car's name and year, leading to lost profit margins or overpriced inventory that scares away buyers. Furthermore, the raw dataset suffers from severe quality issues, with missing fields for critical technical specifications like mileage, engine size, and seat counts, severely hindering confident decision-making.

## ✦ Goals
* **Price Prediction:** Develop a reliable and mathematically stable model to predict the fair selling price of incoming cars.
* **Feature Impact:** Identify and quantify which specific attributes (e.g., kilometers driven, fuel type, ownership history) add or destroy the most value.
* **Data Remediation:** Clean and preprocess the dataset to resolve missing data so every listing provides a complete technical story.

## ✦ Exploratory Data Analysis (EDA), Preprocessing & Transformation
* **Data Cleaning & Extraction:** Raw text strings containing units (e.g., '85 bhp') were parsed to extract pure numeric values for `mileage_num`, `engine_num`, and `max_power_num`. Complex torque strings were split to extract `torque_value` and average `torque_rpm`.
* **Missing Value Imputation:** Missing numeric features were handled using median imputation, while missing categorical features (such as seat counts) were filled using the mode.
* **Feature Engineering:** New predictive metrics were created, including `car_age` (calculated from the model year), `km_per_year` (to measure usage intensity), and `power_to_engine_ratio`, 24].
* **Data Transformation:** Continuous prices were binned into a `price_category_encoded` target (0=Cheap, 1=Average, 2=Expensive) for classification tasks, and continuous features were standardized into Z-scores to scale the data uniformly.

## ✦ Advanced Modeling, Cross Validation & Results
* **Baseline Simple Linear Model:** Established a performance floor with an R-Square of 0.6146 and a Root MSE of 325,820, revealing that automatic transmissions (+326k) and engine power (+318k) are massive value-adds, while age (-151k) acts as the primary value destroyer].
* **Simple LASSO Model (Feature Selection):** Utilized the Cross-Validation (CV PRESS) Criterion to penalize useless variables and prevent overfitting, stopping optimally at 9 features]. It successfully eliminated redundant variables like `engine_num` to fix multicollinearity, trading a tiny bit of R-Square (0.6073) for massive mathematical stability].
* **Polynomial LASSO Regression:** The breakthrough model that captured non-linear trends (e.g., the exponential value of horsepower) and complex feature interactions]. It drove the R-Square up to a highly accurate 0.8388 and slashed the Root MSE down to 217,551, reducing financial risk by over 100k per vehicle]. 
* **Multinomial Logistic Regression:** A tier-based classification model predicting if a car is Cheap, Average, or Expensive, 24]. It revealed massive odds multipliers, indicating a Diesel car is 81.75 times more likely to fall into the Expensive tier compared to the baseline, holding all else equal].

## ✦ Key Insights & Real-World Decision Making
* **The Value Destroyers vs. The Mileage Pivot:** The passage of time (`car_age`) is the absolute harshest penalty on a car's price]. However, the Polynomial model revealed that older cars with high total miles do not lose as much value if their `km_per_year` is low, allowing the dealership to buy older, gently-used cars cheaply and sell them reliably].
* **The Diesel & Automatic Premium:** The Polynomial LASSO model identified the interaction between Diesel engines and Automatic transmissions (`fuelDiesel * transmissionAutoma`) as the ultimate combination for resale value, commanding an estimated +203,687 premium]. 
* **Operational Strategy:** By relying on the optimized LASSO model, the intake team can stop recording useless metrics (like torque or seat counts) and input just 9 key data points to generate a highly accurate price]. The Multinomial Logistic model serves as a "Fast Lane" intake filter to rapidly categorize cars at auction or immediately route "Expensive" trade-ins to senior appraisers].

## ✦ Tools & Technologies
* **Language & Environment:** SAS
* **Key Procedures:** `PROC IMPORT`, `PROC SGPLOT` (EDA & Visualization), `PROC STDIZE` (Standardization & Imputation), `PROC GLMSELECT` (LASSO & Polynomial CV selection), and `PROC LOGISTIC` (Multinomial Logistic Regression).

## ✦ Conclusion
Through rigorous text extraction, missing value imputation, and strategic feature engineering, the messy used car inventory data was successfully transformed into a robust analytical pipeline 22, 24]. By leveraging Cross-Validation and transitioning from a baseline Linear Model to a Polynomial LASSO Regression, the dealership dramatically increased pricing accuracy (R-Square 0.8388) while preventing overfitting]. Ultimately, these advanced models provide actionable, mathematically stable strategies for vehicle sourcing, dynamic pricing, and automated inventory tiering].
