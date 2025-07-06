SAMPLE_QUERY = {
    '''SELECT 'Real Time Dashboard' AS report_name, CASE WHEN cm_event_state_updates.statemachineid = 'operational_status' AND cm_event_state_updates.state.id = 'in_progress' THEN cm_event_assignee_update.username WHEN cm_event_state_updates.state.id IN ( "on_hold", "unreviewed", "fraud", "genuine", "contact_customer", "closed" ) THEN cm_event_state_updates.username END AS analyst_full_name, cm_event_state_updates.payload.schema.alert_id AS alert_id, timestamp_millis( cm_event_state_updates.updatedAt ) AS alert_action_timestamp, cm_event_queue_changed.queueid AS queue_id, queue_reference.Queue_Name AS queue_name, cm_event_state_updates.statemachineid AS statemachineid, cm_event_state_updates.state.id AS stateid, cm_event_arrival.id.identifier AS lifecycle_id, timestamp_diff( timestamp_millis( cm_event_state_updates.updatedAt ), timestamp_millis( cm_event_state_updates_lag.updated_prev ), SECOND ) AS time_diff, CASE WHEN lower( cm_event_state_updates.state.id ) IN ( 'fraud', 'genuine', 'in_progress', 'on_hold', 'closed' ) THEN cm_event_state_updates.name END AS reason_updated, timestamp('2025-02-28 14:00:10.000') AS load_datetime FROM ( SELECT *, lag(username) over( PARTITION BY identifier ORDER BY updatedat DESC ) AS user_next FROM cm_event_state_updates_vw WHERE updatedTimestamp >= timestamp('2025-01-28 14:00:10.000') AND updatedTimestamp < timestamp('2025-03-28 14:00:10.000') ) cm_event_state_updates LEFT JOIN ( SELECT * FROM ( SELECT *, ROW_NUMBER() OVER( PARTITION BY identifier ORDER BY updatedAT DESC ) AS rownum FROM cm_event_assignee_update LEFT JOIN unnest(ids) ) WHERE rownum = 1 ) cm_event_assignee_update ON cm_event_state_updates.identifier = cm_event_assignee_update.identifier LEFT JOIN ( SELECT * FROM ( SELECT *, ROW_NUMBER() OVER( PARTITION BY id.identifier ORDER BY timestamp(cm_event_arrival.timestamp) DESC ) AS rownum FROM cm_event_arrival WHERE lower( cm_event_arrival.id.payload.schema.event_type ) NOT IN ('feedback') ) WHERE rownum = 1 ) cm_event_arrival ON cm_event_state_updates.identifier = cm_event_arrival.id.identifier LEFT JOIN ( SELECT * FROM ( SELECT cm_event_queue_changed.timestamp AS timestamp, cm_event_queue_changed.queueid, identifier, ROW_NUMBER() OVER( PARTITION BY identifier ORDER BY timestamp( cm_event_queue_changed.timestamp ) DESC ) AS rownum FROM cm_event_queue_changed LEFT JOIN unnest(ids) WHERE queueid IS NOT NULL ) WHERE rownum = 1 ) cm_event_queue_changed ON cm_event_state_updates.identifier = cm_event_queue_changed.identifier LEFT JOIN ( SELECT *, lag(username) over( PARTITION BY identifier ORDER BY updatedat DESC ) AS user_next, lag(updatedat) OVER ( PARTITION BY identifier ORDER BY updatedat ) AS updated_prev, lag(state.id) OVER ( PARTITION BY identifier ORDER BY updatedat ) AS stateid_prev FROM cm_event_state_updates_vw ) cm_event_state_updates_lag ON cm_event_state_updates_lag.identifier = cm_event_state_updates.identifier AND cm_event_state_updates.updatedat = cm_event_state_updates_lag.updatedat LEFT JOIN FZ_EU_REPORT_MARTS_TABLES_DEV.queue_reference ON cm_event_queue_changed.queueid = queue_reference.Queue_Id WHERE lower(cm_event_arrival.id.channelid) IN ('transfers') AND lower( cm_event_state_updates.statemachineid ) IN ("operational_status", "status") AND lower( cm_event_state_updates.state.id ) IN ( "on_hold", "in_progress", "unreviewed", "fraud", "genuine", "contact_customer", "pending_manual_closure", "pending_crypto_reversal_sms", "pending_bot_closure", "closed", "wait_to_contact_customer" ) AND lower( cm_event_arrival.id.payload.schema.event_type ) IN ('transfer_initiation') AND cm_event_arrival.alert = TRUE'''
    :
    '''
        SELECT 
            'Real Time Dashboard' AS report_name,

            CASE 
                WHEN cm_event_state_updates.statemachineid = 'operational_status' 
                    AND cm_event_state_updates.state.id = 'in_progress' 
                THEN cm_event_assignee_update.username 
                WHEN cm_event_state_updates.state.id IN ("on_hold", "unreviewed", "fraud", "genuine", "contact_customer", "closed") 
                THEN cm_event_state_updates.username 
            END AS analyst_full_name,

            cm_event_state_updates.payload.schema.alert_id AS alert_id,
            TIMESTAMP_MILLIS(cm_event_state_updates.updatedAt) AS alert_action_timestamp,
            cm_event_queue_changed.queueid AS queue_id,
            queue_reference.Queue_Name AS queue_name,
            cm_event_state_updates.statemachineid AS statemachineid,
            cm_event_state_updates.state.id AS stateid,
            cm_event_arrival.id.identifier AS lifecycle_id,

            TIMESTAMP_DIFF(
                TIMESTAMP_MILLIS(cm_event_state_updates.updatedAt), 
                TIMESTAMP_MILLIS(cm_event_state_updates_lag.updated_prev), 
                SECOND
            ) AS time_diff,

            CASE 
                WHEN LOWER(cm_event_state_updates.state.id) IN ('fraud', 'genuine', 'in_progress', 'on_hold', 'closed') 
                THEN cm_event_state_updates.name 
            END AS reason_updated,

            TIMESTAMP('2025-02-28 14:00:10.000') AS load_datetime

        FROM 
        (
            SELECT *, 
                LAG(username) OVER (PARTITION BY identifier ORDER BY updatedAt DESC) AS user_next   
            FROM cm_event_state_updates_vw 
            WHERE updatedTimestamp BETWEEN TIMESTAMP('2025-01-28 14:00:10.000') 
                                    AND TIMESTAMP('2025-03-28 14:00:10.000')
        ) cm_event_state_updates

        LEFT JOIN (
            SELECT * 
            FROM (
                SELECT *, 
                    ROW_NUMBER() OVER (PARTITION BY identifier ORDER BY updatedAT DESC) AS rownum 
                FROM cm_event_assignee_update 
                LEFT JOIN UNNEST(ids)
            ) 
            WHERE rownum = 1
        ) cm_event_assignee_update
        ON cm_event_state_updates.identifier = cm_event_assignee_update.identifier

        LEFT JOIN (
            SELECT * 
            FROM (
                SELECT *, 
                    ROW_NUMBER() OVER (PARTITION BY id.identifier ORDER BY TIMESTAMP(cm_event_arrival.timestamp) DESC) AS rownum 
                FROM cm_event_arrival 
                WHERE LOWER(cm_event_arrival.id.payload.schema.event_type) NOT IN ('feedback') 
            ) 
            WHERE rownum = 1
        ) cm_event_arrival
        ON cm_event_state_updates.identifier = cm_event_arrival.id.identifier

        LEFT JOIN (
            SELECT identifier, queueid, timestamp
            FROM (
                SELECT identifier, 
                    cm_event_queue_changed.timestamp, 
                    cm_event_queue_changed.queueid, 
                    ROW_NUMBER() OVER (PARTITION BY identifier ORDER BY TIMESTAMP(cm_event_queue_changed.timestamp) DESC) AS rownum 
                FROM cm_event_queue_changed 
                LEFT JOIN UNNEST(ids)
                WHERE queueid IS NOT NULL
            ) 
            WHERE rownum = 1
        ) cm_event_queue_changed
        ON cm_event_state_updates.identifier = cm_event_queue_changed.identifier

        LEFT JOIN (
            SELECT identifier, updatedAt, username,
                LAG(updatedAt) OVER (PARTITION BY identifier ORDER BY updatedAt) AS updated_prev
            FROM cm_event_state_updates_vw
        ) cm_event_state_updates_lag
        ON cm_event_state_updates_lag.identifier = cm_event_state_updates.identifier
        AND cm_event_state_updates.updatedAt = cm_event_state_updates_lag.updatedAt                        

        LEFT JOIN queue_reference
        ON cm_event_queue_changed.queueid = queue_reference.Queue_Id

        WHERE 
            LOWER(cm_event_arrival.id.channelid) IN ('transfers')
            AND LOWER(cm_event_state_updates.statemachineid) IN ("operational_status", "status")
            AND LOWER(cm_event_state_updates.state.id) IN (
                "on_hold", "in_progress", "unreviewed", "fraud", "genuine", 
                "contact_customer", "pending_manual_closure", 
                "pending_crypto_reversal_sms", "pending_bot_closure", "closed", 
                "wait_to_contact_customer"
            )
            AND LOWER(cm_event_arrival.id.payload.schema.event_type) IN ('transfer_initiation')
            AND cm_event_arrival.alert = TRUE;
    ''',
    '''SELECT sender_transaction_currency, event_type, CASE  WHEN sender_transaction_amount <= 100 THEN 'Small' WHEN sender_transaction_amount <= 1000 THEN 'Medium' WHEN sender_transaction_amount <= 10000 THEN 'Large' ELSE 'Very Large' END as amount_category, COUNT(*) as transaction_count, SUM(sender_transaction_amount) as category_total, MIN(sender_transaction_amount) as min_amount, MAX(sender_transaction_amount) as max_amount FROM event_store GROUP BY sender_transaction_currency, event_type, amount_category ORDER BY sender_transaction_currency, category_total DESC;'''
    :
    '''
    SELECT
           sender_transaction_currency,
           event_type,
           CASE
               WHEN sender_transaction_amount <= 100 THEN 'Small'
               WHEN sender_transaction_amount <= 1000 THEN 'Medium'
               WHEN sender_transaction_amount <= 10000 THEN 'Large'
               ELSE 'Very Large'
               END as amount_category,
           COUNT(*) as transaction_count,
           SUM(sender_transaction_amount) as category_total,
           MIN(sender_transaction_amount) as min_amount,
           MAX(sender_transaction_amount) as max_amount
       FROM event_store
       WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
         AND sender_transaction_currency IS NOT NULL
         AND sender_transaction_amount IS NOT NULL
         AND event_type IS NOT NULL
       GROUP BY sender_transaction_currency, event_type, amount_category
       HAVING COUNT(*) >= 3
       ORDER BY sender_transaction_currency, category_total DESC
           LIMIT 100;
    ''',
    '''SELECT UPPER(TRIM(sender_transaction_currency)) as clean_currency, LOWER(TRIM(event_type)) as clean_event_type, COUNT(*) as transaction_count, SUM(CAST(sender_transaction_amount AS FLOAT64)) as total_amount, AVG(CAST(sender_transaction_amount AS FLOAT64)) as avg_amount, CASE  WHEN UPPER(TRIM(sender_transaction_currency)) = 'USD' THEN 'US Dollar' WHEN UPPER(TRIM(sender_transaction_currency)) = 'EUR' THEN 'Euro' WHEN UPPER(TRIM(sender_transaction_currency)) = 'INR' THEN 'Indian Rupee' ELSE CONCAT('Other: ', UPPER(TRIM(sender_transaction_currency))) END as currency_name FROM event_store WHERE sender_transaction_amount IS NOT NULL AND TRIM(sender_transaction_currency) != '' AND TRIM(event_type) != ''GROUP BY UPPER(TRIM(sender_transaction_currency)), LOWER(TRIM(event_type)) ORDER BY total_amount DESC;'''
    :
    '''
    WITH cleaned_data AS (
        SELECT
            UPPER(TRIM(sender_transaction_currency)) as clean_currency,
            LOWER(TRIM(event_type)) as clean_event_type,
            sender_transaction_amount
        FROM event_store
        WHERE sender_transaction_amount IS NOT NULL
          AND TRIM(sender_transaction_currency) != ''
           AND TRIM(event_type) != ''
           )
    SELECT
        clean_currency,
        clean_event_type,
        COUNT(*) as transaction_count,
        SUM(sender_transaction_amount) as total_amount,
        AVG(sender_transaction_amount) as avg_amount,
        CASE clean_currency
            WHEN 'USD' THEN 'US Dollar'
            WHEN 'EUR' THEN 'Euro'
            WHEN 'INR' THEN 'Indian Rupee'
            ELSE CONCAT('Other: ', clean_currency)
            END as currency_name
    FROM cleaned_data
    GROUP BY clean_currency, clean_event_type
    ORDER BY total_amount DESC
        LIMIT 50;''',
    '''SELECT lifecycle_id, event_type, sender_transaction_amount, CASE WHEN REGEXP_CONTAINS(LOWER(event_type), r'.*payment.*') THEN 'Payment Related' WHEN REGEXP_CONTAINS(LOWER(event_type), r'.*transfer.*') THEN 'Transfer Related' WHEN REGEXP_CONTAINS(LOWER(event_type), r'.*verification.*') THEN 'Verification Related' WHEN REGEXP_CONTAINS(LOWER(event_type), r'.*review.*') THEN 'Review Related' ELSE 'Other' END as event_category, CASE WHEN LENGTH(lifecycle_id) > 20 THEN 'Long ID' WHEN LENGTH(lifecycle_id) > 10 THEN 'Medium ID' ELSE 'Short ID' END as id_length_category, CONCAT(SUBSTR(lifecycle_id, 1, 3), '...', SUBSTR(lifecycle_id, -3)) as masked_id FROM event_storeWHERE lifecycle_id IS NOT NULL AND event_type IS NOT NULL AND REGEXP_CONTAINS(lifecycle_id, r'^[A-Za-z0-9]+$') ORDER BY sender_transaction_amount DESC;'''
    :
    '''
    WITH processed_events AS (
        SELECT
            lifecycle_id,
            event_type,
            sender_transaction_amount,
            LOWER(event_type) as lower_event_type,
            LENGTH(lifecycle_id) as id_length
        FROM event_store
        WHERE lifecycle_id IS NOT NULL
          AND event_type IS NOT NULL
          AND REGEXP_CONTAINS(lifecycle_id, r'^[A-Za-z0-9]+$')
          AND sender_transaction_amount > 0
    )
    SELECT
        lifecycle_id,
        event_type,
        sender_transaction_amount,
        CASE
            WHEN lower_event_type LIKE '%payment%' THEN 'Payment Related'
            WHEN lower_event_type LIKE '%transfer%' THEN 'Transfer Related'
            WHEN lower_event_type LIKE '%verification%' THEN 'Verification Related'
            WHEN lower_event_type LIKE '%review%' THEN 'Review Related'
            ELSE 'Other'
            END as event_category,
        CASE
            WHEN id_length > 20 THEN 'Long ID'
            WHEN id_length > 10 THEN 'Medium ID'
            ELSE 'Short ID'
            END as id_length_category,
        CONCAT(SUBSTR(lifecycle_id, 1, 3), '...', SUBSTR(lifecycle_id, -3)) as masked_id
    FROM processed_events
    ORDER BY sender_transaction_amount DESC
        LIMIT 100;
    ''',
    '''SELECT e1.lifecycle_id, e1.event_type as first_event, e1.sender_transaction_amount as first_amount, e2.event_type as second_event, e2.sender_transaction_amount as second_amount, ABS(e1.sender_transaction_amount - e2.sender_transaction_amount) as amount_diff, CASE WHEN e1.sender_transaction_amount > e2.sender_transaction_amount THEN 'Increasing'    WHEN e1.sender_transaction_amount < e2.sender_transaction_amount THEN 'Decreasing'    ELSE 'Same' END as trend, CONCAT(UPPER(LEFT(e1.event_type, 3)), '-', UPPER(LEFT(e2.event_type, 3))) as event_pair_code FROM event_store e1 JOIN event_store e2 ON e1.lifecycle_id = e2.lifecycle_id AND e1.created_at < e2.created_at AND CAST(e1.sender_transaction_amount AS STRING) != CAST(e2.sender_transaction_amount AS STRING) WHERE e1.sender_transaction_amount IS NOT NULL AND e2.sender_transaction_amount IS NOT NULL AND TRIM(e1.event_type) != TRIM(e2.event_type) ORDER BY amount_diff DESC;'''
    :
    '''
    WITH numbered_events AS (
        SELECT
            lifecycle_id,
            event_type,
            sender_transaction_amount,
            created_at,
            ROW_NUMBER() OVER (PARTITION BY lifecycle_id ORDER BY created_at) as event_sequence
        FROM event_store
        WHERE sender_transaction_amount IS NOT NULL
          AND event_type IS NOT NULL
          AND lifecycle_id IS NOT NULL
    ),
         event_pairs AS (
             SELECT
                 e1.lifecycle_id,
                 e1.event_type as first_event,
                 e1.sender_transaction_amount as first_amount,
                 e2.event_type as second_event,
                 e2.sender_transaction_amount as second_amount,
                 ABS(e1.sender_transaction_amount - e2.sender_transaction_amount) as amount_diff
             FROM numbered_events e1
                      INNER JOIN numbered_events e2
                                 ON e1.lifecycle_id = e2.lifecycle_id
                                     AND e2.event_sequence = e1.event_sequence + 1
             WHERE e1.sender_transaction_amount != e2.sender_transaction_amount
        AND e1.event_type != e2.event_type
        )
    SELECT
        lifecycle_id,
        first_event,
        first_amount,
        second_event,
        second_amount,
        amount_diff,
        CASE
            WHEN first_amount > second_amount THEN 'Decreasing'
            WHEN first_amount < second_amount THEN 'Increasing'
            ELSE 'Same'
            END as trend,
        CONCAT(SUBSTR(first_event, 1, 3), '-', SUBSTR(second_event, 1, 3)) as event_pair_code
    FROM event_pairs
    WHERE amount_diff > 0
    ORDER BY amount_diff DESC
        LIMIT 50;
    '''
}
