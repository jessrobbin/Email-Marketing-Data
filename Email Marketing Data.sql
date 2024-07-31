--CTE aggregates the campaign_recipient table to pull the total number of sends per email

WITH cte AS (
    SELECT
        cr.campaign_id,
        COUNT(DISTINCT member_id) AS No_of_sends
    FROM
        campaign_recipient AS cr
    GROUP BY
        cr.campaign_id
),

--Pulling relevant fields from table
activity AS (
    SELECT
        cra.campaign_id,
        cra.member_id,
        action,
        cra.timestamp,
        ip,
        cra.list_id,
        type,
        create_time,
        c.status,
        send_time,
        title,
        to_name,
        subject_line,
        from_name,
        reply_to,
        track_html_clicks,
        track_text_clicks,
        track_goals,
        track_opens,
        No_of_sends,
        unsub.timestamp AS unsub_timestamp,
        reason AS unsub_reason,
        LENGTH(subject_line) AS subline_char_length, --calculating lenth of subject line
        
      --Marking if Subject Line contains a question mark
        CASE 
            WHEN subject_line LIKE '%?%' THEN 1 
            ELSE 0 
        END AS contains_question_mark,

        --Marking if Subject Line contain recipients first name
        CASE 
            WHEN subject_line LIKE '%*|FNAME|*%' THEN 1 
            ELSE 0 
        END AS contains_recipient_name,

        --Binning subject line lenght
        CASE
            WHEN LENGTH(subject_line) BETWEEN 14 AND 30 THEN '14-30'
            WHEN LENGTH(subject_line) BETWEEN 31 AND 50 THEN '31-50'
            WHEN LENGTH(subject_line) BETWEEN 51 AND 80 THEN '51-80'
            WHEN LENGTH(subject_line) BETWEEN 81 AND 100 THEN '81-100'
            WHEN LENGTH(subject_line) BETWEEN 101 AND 122 THEN '101-122'
            ELSE 'Out of range'
        END AS Subline_Lenth_Bin

        --Finding the first word of the subject line
        ,CASE 
            WHEN CHARINDEX(' ', c.subject_line) > 0 THEN SUBSTRING(c.subject_line, 1, CHARINDEX(' ', c.subject_line) - 1)
            ELSE c.subject_line
        END AS first_word

        --Due to granularity, need to assing a ranking to each action, so can find the highest ranking action for each recipient, for each email
        ,CASE
            WHEN action = 'click' THEN 3
            WHEN action = 'open' THEN 2
            WHEN action = 'bounce' THEN 1
        END AS action_rating

        --Creating an unsub flag column
        ,CASE
            WHEN unsub_reason IS NOT NULL then 1
            ELSE 0
        END AS unsub_flag
          
    FROM
        CAMPAIGN_RECIPIENT_ACTIVITY AS cra
    LEFT JOIN
        campaign AS c ON c.id = cra.campaign_id
    LEFT JOIN
        unsubscribe AS unsub ON unsub.campaign_id = cra.campaign_id AND cra.member_id = unsub.member_id
    LEFT JOIN
        cte ON cte.campaign_id = cra.campaign_id
)
SELECT
    *
FROM
    activity

--Final Granularity = one interaction by a member on an email. (Multiple rows for a member per email)
