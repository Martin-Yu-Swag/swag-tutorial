# Order Failed

- in each payment service provider, posses a callback function `notify_order_status_failed`
  - Send `shop` Signal `order.failed`
    - metadata: order.metadata.get('_task_')
    - **args**: order_id
    - **receivers**
      - track_transaction
      - `notify_order_status`
        - targets: `presence-user@{user_id}`
        - event: "purchase.failed"
      - `update_order_status_canceled`
        (later will be clean up by scheduled task)
        - !!!Update `Order`
          - filter
            - id
            - status_transitions__paid__exists=False
          - update_one
            - min__status_transitions__canceled now

