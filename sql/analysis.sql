-- ============================================================
-- Texas Airbnb Price Analysis — SQL Analysis
-- ============================================================
-- Business Question: What factors most influence Airbnb listing
-- prices across major Texas cities, and how can hosts use these
-- insights to price their properties competitively?
--
-- To answer this question the following sub-questions were explored:
-- Q1:  What is the average price per night by city?
-- Q2:  What is the average price by room type per city?
-- Q3:  What are the top 10 most expensive neighbourhoods per city?
-- Q4:  Does listing availability affect price?
-- Q5:  How does host listing count affect price?
-- Q6:  What is the percentage of listings by room type per city?
-- Q7:  What is the availability of listings by price range per city?
-- Q8:  How does minimum night requirement relate to price?
-- Q9:  What are the top 10 most expensive neighbourhoods across all cities?
-- Q10: What does the overall city comparison summary look like?
-- ============================================================




-------------------------------------------------------------------------------------

-- Q1: What is the average price per night by city

-- Finding: Dallas is surprisingly the most expensive city on average,
-- followed by Austin and Fort Worth as the most affordable option

SELECT city, ROUND(AVG(price)::numeric, 2) AS avg_cost_per_night
FROM listings
GROUP BY city;

-------------------------------------------------------------------------------------

-- Q2: What is the average price by room type per city

-- Finding: Hotel rooms in Austin ($289) are surprisingly more expensive than entire homes ($213)
-- Dallas entire homes ($283) are the most expensive listing type across all three cities
-- Private rooms are consistently the most affordable option for travelers across all cities
-- Fort Worth is the cheapest city regardless of room type

SELECT city, room_type, ROUND(AVG(price)::numeric, 2) AS avg_price
FROM listings
GROUP BY city, room_type
ORDER BY city, avg_price DESC;

-------------------------------------------------------------------------------------

-- Q3: What are the top 10 most expensive neighbourhoods per city

-- Finding: Despite Dallas having a higher overall average price than Austin,
-- Austin's most expensive zip code (78730) averages $510/night — nearly $200 more
-- than Dallas's most expensive district (District 13 at $334/night)
-- This suggests Austin has a wider price range with some ultra premium areas
-- driving up variability while Dallas is more consistently priced across districts
-- Fort Worth remains the most affordable city across all neighbourhoods
--
-- Limitation: Neighbourhood data is inconsistent across cities — Austin uses
-- zip codes while Dallas and Fort Worth use district names, preventing direct
-- cross-city neighbourhood comparison
-- Limitation: "Unknown" appears as rank 4 in Fort Worth due to 956 listings
-- with missing neighbourhood data that were filled with 'Unknown' during cleaning
-- Fort Worth neighbourhood results should be interpreted with caution

WITH area_cost AS(
	SELECT city, neighbourhood, AVG(price) AS avg_price
	FROM listings
	GROUP BY city, neighbourhood
),
area_cost_ranked AS (
	SELECT *, RANK() OVER(PARTITION BY city ORDER BY avg_price DESC) AS price_rank
	FROM area_cost
)

SELECT *
FROM area_cost_ranked
WHERE price_rank <= 10;

-------------------------------------------------------------------------------------

-- Q4: Does listing availability affect price?

-- Finding: Counter-intuitively, listings with higher availability tend to
-- command higher average prices across all three cities
-- Low availability listings (0-90 days) average the lowest price suggesting
-- casual hosts who only open their listing occasionally and price conservatively
-- High availability listings (271-365 days) average the highest price
-- suggesting professional hosts who list year round and price aggressively
-- Minor discrepancy between 91-180 and 181-270 buckets is likely natural
-- data variation rather than a meaningful trend
-- 
-- Limitation: availability_365 represents days open for booking, not days
-- actually booked -- a more complete analysis would require calendar.csv
-- data to determine actual occupancy rates and true demand
--
-- Future Improvement: incorporate calendar.csv data to analyze actual
-- occupancy rates, giving a more accurate picture of listing demand
-- and whether low availability truly signals high demand

WITH availability_groups AS (
    SELECT price,
        CASE
            WHEN availability_365 BETWEEN 0 AND 90 THEN '0 to 90 days available'
            WHEN availability_365 BETWEEN 91 AND 180 THEN '91 to 180 days available'
            WHEN availability_365 BETWEEN 181 AND 270 THEN '181 to 270 days available'
            WHEN availability_365 BETWEEN 271 AND 365 THEN '271 to 365 days available'
        END AS availability_bucket
    FROM listings
)
SELECT availability_bucket, ROUND(AVG(price)::numeric, 2) AS avg_price
FROM availability_groups
GROUP BY availability_bucket
ORDER BY 
    CASE availability_bucket
        WHEN '0 to 90 days available' THEN 1
        WHEN '91 to 180 days available' THEN 2
        WHEN '181 to 270 days available' THEN 3
        WHEN '271 to 365 days available' THEN 4
    END;

-------------------------------------------------------------------------------------

-- Q5: How does host listing count affect price?

-- Finding: Single listing hosts charge the highest average price ($229)
-- while hosts with 2-5 listings charge the least ($199) and 6+ hosts
-- fall in the middle ($207)
-- Single listing hosts likely rent out one premium personal property
-- occasionally, or may be pricing aggressively to maximize revenue
-- from their only listing
-- Hosts with 2-5 listings may focus on volume over premium pricing,
-- potentially managing smaller or duplex style properties
-- Hosts with 6+ listings show a slight price recovery, possibly indicating
-- they can afford to maintain multiple higher quality properties
-- Note: The overall price range across all groups is relatively small ($30)
-- suggesting host listing count is not a major pricing driver compared
-- to room type or location which showed significantly larger price differences

WITH listing_groups AS (
	SELECT price,
		CASE 
			WHEN calculated_host_listings_count = 1 THEN '1'
			WHEN calculated_host_listings_count BETWEEN 2 AND 5 THEN '2 to 5'
			WHEN calculated_host_listings_count>= 6 THEN '6+'
		END AS number_of_listings
	FROM listings
)

SELECT number_of_listings, ROUND(AVG(price)::numeric, 2) AS avg_price
FROM listing_groups
GROUP BY number_of_listings;

-------------------------------------------------------------------------------------

-- Q6: What is the percentage of listings by room type per city

-- Finding: Entire homes/apartments dominate all three cities making up
-- 87% of Austin, 87% of Dallas and 79% of Fort Worth listings
-- This suggests the Texas Airbnb market is heavily skewed toward
-- entire home rentals which aligns with guest preferences for
-- privacy and having a space entirely to themselves
-- Fort Worth stands out with a higher private room percentage (20%)
-- compared to Austin (12%) and Dallas (11%), suggesting a more
-- diverse and budget friendly listing mix
-- Hotel rooms make up less than 1-2% across all cities, likely due
-- to the difficulty of subletting hotel rooms and only a small number
-- of hotels choosing to list individual rooms on Airbnb
-- Shared rooms are negligible across all three cities at under 1%

WITH listing_table AS (
	SELECT city, room_type, COUNT(room_type) AS num_listings
	FROM listings
	GROUP BY city, room_type
	ORDER BY city ASC
),
listing_table_sum AS (
	SELECT *, SUM(num_listings) OVER(PARTITION BY city)
	FROM listing_table
)
SELECT city, room_type, ROUND(((num_listings / sum) * 100),2) AS percent_of_room_type_listings
FROM listing_table_sum

-------------------------------------------------------------------------------------

-- Q7: What is the availability of listings by price range per city

-- Finding: Availability is surprisingly consistent across all price ranges
-- in every city, averaging between 230-270 days per year regardless of
-- whether the listing is Budget or Premium
-- This suggests hosts across all price tiers tend to keep their listings
-- open for a similar number of days annually
-- Note: availability_365 represents days open for booking, not days actually
-- booked -- conclusions about actual demand cannot be drawn from this data alone
-- A more meaningful analysis would require calendar.csv booking data to
-- determine true occupancy rates across price ranges

WITH price_table AS (
	SELECT city, price, availability_365,
		CASE 
			WHEN price BETWEEN 0 AND 100 THEN 'Budget'
			WHEN price BETWEEN 101 AND 200 THEN 'Mid Range'
			WHEN price BETWEEN 201 AND 350 THEN 'Upper Range'
			WHEN price >= 351 THEN	'Premium'
		END AS cost_of_airbnb
	FROM listings

),
price_table_group AS (
	SELECT city, cost_of_airbnb,
		COUNT(*) AS num_listings,
        ROUND(AVG(availability_365)::numeric, 0) AS avg_availability
	FROM price_table
	GROUP BY city, cost_of_airbnb
)

SELECT *
FROM price_table_group
ORDER BY city, avg_availability DESC;

-------------------------------------------------------------------------------------

-- Q8: How does minimum night requirement relate to price?

-- Finding: Listings requiring 2-6 night minimums command the highest
-- average price ($247) suggesting this is the sweet spot where host
-- pricing power is strongest due to high traveler demand for short vacations
-- Price decreases as minimum stay increases beyond 6 nights
-- suggesting hosts lower nightly rates to incentivize longer bookings
-- and guarantee more stable income over a longer period
-- Recommendation for hosts: A 2-6 night minimum appears to be the
-- optimal strategy for maximizing nightly rate while still attracting
-- the largest pool of typical vacationing travelers

WITH stay_table AS(
	SELECT price,
		CASE
			WHEN minimum_nights = 1 THEN '1 Night'
			WHEN minimum_nights BETWEEN 2 AND 6 THEN '2 to 6 Nights'
			WHEN minimum_nights = 7 THEN '7 Nights'
			WHEN minimum_nights >= 8 THEN '8+ Nights'
		END AS minimum_stay_amount
	FROM listings
)

SELECT minimum_stay_amount, ROUND(AVG(price)::numeric,2) AS avg_price
FROM stay_table
GROUP BY minimum_stay_amount
ORDER BY
	CASE minimum_stay_amount
		WHEN '1 Night' THEN 1
		WHEN '2 to 6 Nights' THEN 2
		WHEN '7 Nights' THEN 3
		WHEN '8+ Nights' THEN 4
	END;
	
-------------------------------------------------------------------------------------

-- Q9: Top 10 most expensive neighbourhoods across all three cities

-- Finding: Austin dominates the top 4 spots with zip code 78730 averaging
-- $509/night -- nearly $175 more than the 5th ranked neighbourhood
-- Dallas appears consistently from rank 5-10 with a tight price spread
-- across its top districts suggesting more evenly distributed premium
-- neighbourhoods compared to Austin's concentrated luxury areas
-- Fort Worth does not appear in the top 10 at all, confirming it as
-- the most affordable market across all neighbourhoods
-- Recommendations for hosts:
-- Hosts seeking to maximize nightly rates should target Austin real estate
-- as it is the most accepted market for premium pricing
-- Dallas offers more options for premium listings with multiple districts
-- commanding similar high prices
-- Fort Worth may represent an untapped luxury market opportunity --
-- with little premium competition, a well positioned high end listing
-- could stand out significantly in an otherwise budget friendly market

WITH price_table AS (
	SELECT city, neighbourhood, AVG(price) AS avg_price
	FROM listings
	GROUP BY city, neighbourhood
),
price_table_rank AS(
	SELECT *, RANK() OVER(ORDER BY avg_price DESC)
	FROM price_table
)

SELECT * 
FROM price_table_rank
WHERE rank <= 10;
 
-------------------------------------------------------------------------------------

-- Q10: City comparison summary

-- Finding: Dallas commands the highest average nightly price ($264) but
-- Austin is the most active market with 10,020 listings and the highest
-- average review count (58) suggesting stronger overall booking demand
-- Fort Worth is the most affordable city ($140) with high availability
-- (255 days) and the fewest listings -- representing an underserved
-- market with potential opportunity for new hosts
-- Note: avg_reviews used as a relative proxy for booking activity --
-- actual booking data would require calendar.csv for precise measurement

SELECT city, 
    ROUND(AVG(price)::numeric, 2) AS avg_price_per_night, 
    ROUND(AVG(availability_365)::numeric, 0) AS avg_availability_year_round, 
    ROUND(AVG(number_of_reviews)::numeric, 1) AS avg_reviews, 
    COUNT(*) AS total_listings
FROM listings
GROUP BY city
ORDER BY avg_price_per_night DESC;



