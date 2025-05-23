# Aggregations By Example

## 3.1 Foundational Examples

### Filtered Top Subset

`$match`, `$sort`, `$limit`, `$unset`

```js
// Match engineers only
{"$match": {
    "vocation": "ENGINEER",
}},
// Sort by youngest person first
{"$sort": {
    "dateofbirth": -1,
}},      
// Only include the first 3 youngest people
{"$limit": 3},  
// Exclude unrequired fields from each person record
{"$unset": [
    "_id",
    "vocation",
    "address",
]},
```

### Group & Total

`$match`, `$sort`, `$group`, `$sort`, `$set`, `$unset`

```js
// Match only orders made in 2020
{"$match": {
    "orderdate": {
        "$gte": ISODate("2020-01-01T00:00:00Z"),
        "$lt": ISODate("2021-01-01T00:00:00Z"),
    },
}},
// Sort by order date ascending (required to pick out 'first_purchase_date' below)
{"$sort": {
    "orderdate": 1,
}},      
// Group by customer
{"$group": {
    "_id": "$customer_id",
    "first_purchase_date": {"$first": "$orderdate"},
    "total_value": {"$sum": "$value"},
    "total_orders": {"$sum": 1},
    "orders": {"$push": {"orderdate": "$orderdate", "value": "$value"}},
}},
// Sort by each customer's first purchase date
{"$sort": {
    "first_purchase_date": 1,
}},    
// Set customer's ID to be value of the field that was grouped on
{"$set": {
    "customer_id": "$_id",
}},
// Omit unwanted fields
{"$unset": [
    "_id",
]},
```

### Unpack Arrays & Group Differently

`$unwind`, `$match`, `$group`, `$set`, `$unset`

```js
var pipeline = [
  // Unpack each product from each order's product as a new separate record
  {"$unwind": {
    "path": "$products",
  }},

  // Match only products valued greater than 15.00
  {"$match": {
    "products.price": {
      "$gt": NumberDecimal("15.00"),
    },
  }},
  
  // Group by product type, capturing each product's total value + quantity
  {"$group": {
    "_id": "$products.prod_id",
    "product": {"$first": "$products.name"},
    "total_value": {"$sum": "$products.price"},
    "quantity": {"$sum": 1},
  }},

  // Set product id to be the value of the field that was grouped on
  {"$set": {
    "product_id": "$_id",
  }},
  
  // Omit unwanted fields
  {"$unset": [
    "_id",
  ]},   
];
```

### Distinct List Of Values

`$unwind`, `$group`, `$sort`, `$set`

```js
var pipeline = [
  // Unpack each language field which may be an array or a single value
  {"$unwind": {
    "path": "$language",
  }},
  
  // Group by language
  {"$group": {
    "_id": "$language",
  }},
  
  // Sort languages alphabetically
  {"$sort": {
    "_id": 1,
  }}, 
  
  // Change _id field's name to 'language'
  {"$set": {
    "language": "$_id",
    "_id": "$$REMOVE",     
  }},
];
```

- **Unwinding Non-Arrays**
  if the field is not an array, the stage outputs a single record using the field's value
- **Group ID Provides Unique Values**

---

## 3.2 Joining Data Examples

### One-to-One Join

```js
var pipeline = [
  // Match only orders made in 2020
  {"$match": {
    "orderdate": {
      "$gte": ISODate("2020-01-01T00:00:00Z"),
      "$lt": ISODate("2021-01-01T00:00:00Z"),
    }
  }},

  // Join "product_id" in orders collection to "id" in products" collection
  {"$lookup": {
    "from": "products",
    "localField": "product_id",
    "foreignField": "id",
    "as": "product_mapping",
  }},

  // For this data model, will always be 1 record in right-side
  // of join, so take 1st joined array element
  {"$set": {
    "product_mapping": {"$first": "$product_mapping"},
  }},
  
  // Extract the joined embeded fields into top level fields
  {"$set": {
    "product_name": "$product_mapping.name",
    "product_category": "$product_mapping.category",
  }},
  
  // Omit unwanted fields
  {"$unset": [
    "_id",
    "product_id",
    "product_mapping",
  ]},     
];
```

### Multi-Field Join & One-to-Many

```js
var pipeline = [
  // Join by 2 fields in products collection to 2 fields in orders collection
  {"$lookup": {
    "from": "orders",
    "let": {
      "prdname": "$name",
      "prdvartn": "$variation",
    },
    // Embedded pipeline to control how the join is matched
    "pipeline": [
      // Join by two fields in each side
      {"$match":
        {"$expr":
          {"$and": [
            {"$eq": ["$product_name",  "$$prdname"]},
            {"$eq": ["$product_variation",  "$$prdvartn"]},            
          ]},
        },
      },

      // Match only orders made in 2020
      {"$match": {
        "orderdate": {
          "$gte": ISODate("2020-01-01T00:00:00Z"),
          "$lt": ISODate("2021-01-01T00:00:00Z"),
        }
      }},
      
      // Exclude some unwanted fields from the right side of the join
      {"$unset": [
        "_id",
        "product_name",
        "product_variation",
      ]},
    ],
    as: "orders",
  }},

  // Only show products that have at least one order
  {"$match": {
    "orders": {"$ne": []},
  }},

  // Omit unwanted fields
  {"$unset": [
    "_id",
  ]}, 
];
```

## 3.3. Data Types Conversion Examples

### Strongly-Typed Conversion

```js
var pipeline = [
  // Convert strings to required types
  {"$set": {
    "order_date": {"$toDate": "$order_date"},    
    "value": {"$toDecimal": "$value"},
    "further_info.item_qty": {"$toInt": "$further_info.item_qty"},
    "further_info.reported": {"$switch": {
      "branches": [
        {"case": {"$eq": [{"$toLower": "$further_info.reported"}, "true"]}, "then": true},
        {"case": {"$eq": [{"$toLower": "$further_info.reported"}, "false"]}, "then": false},
      ],
      "default": {"$ifNull": ["$further_info.reported", "$$REMOVE"]},
    }},     
  }},     
  
  // Output to an unsharded or sharded collection
  {"$merge": {
    "into": "orders_typed",
  }},    
];
```

- Boolean Conversion
- Preserving Non-Existence
- Output To A Collection
- Trickier Date Conversions. 

### Convert Incomplete Date Strings

```js
var pipeline = [
  // Change field from a string to a date, filling in the gaps
  {"$set": {
    "paymentDate": {    
      "$let": {
        "vars": {
          "txt": "$paymentDate",  // Assign "paymentDate" field to variable "txt",
          "month": {"$substrCP": ["$paymentDate", 3, 3]},  // Extract month text
        },
        "in": { 
          "$dateFromString": {"format": "%d-%m-%Y %H.%M.%S.%L", "dateString":
            {"$concat": [
              {"$substrCP": ["$$txt", 0, 3]},  // Use 1st 3 chars in string
              {"$switch": {"branches": [  // Replace month 3 chars with month number
                {"case": {"$eq": ["$$month", "JAN"]}, "then": "01"},
                {"case": {"$eq": ["$$month", "FEB"]}, "then": "02"},
                {"case": {"$eq": ["$$month", "MAR"]}, "then": "03"},
                {"case": {"$eq": ["$$month", "APR"]}, "then": "04"},
                {"case": {"$eq": ["$$month", "MAY"]}, "then": "05"},
                {"case": {"$eq": ["$$month", "JUN"]}, "then": "06"},
                {"case": {"$eq": ["$$month", "JUL"]}, "then": "07"},
                {"case": {"$eq": ["$$month", "AUG"]}, "then": "08"},
                {"case": {"$eq": ["$$month", "SEP"]}, "then": "09"},
                {"case": {"$eq": ["$$month", "OCT"]}, "then": "10"},
                {"case": {"$eq": ["$$month", "NOV"]}, "then": "11"},
                {"case": {"$eq": ["$$month", "DEC"]}, "then": "12"},
               ], "default": "ERROR"}},
              "-20",  // Add hyphen + hardcoded century 2 digits
              {"$substrCP": ["$$txt", 7, 15]}  // Use time up to 3 millis (ignore last 6 nanosecs)
            ]
          }}                  
        }
      }        
    },             
  }},

  // Omit unwanted fields
  {"$unset": [
    "_id",
  ]},         
];
```

- Temporary Reusable Variables (by `$let`)

---

## 3.4. Trend Analysis Examples

### Faceted Classification

## 3.5. Securing Data Examples

## 3.6. Time-Series Examples

## 3.7. Array Manipulation Examples

## 3.8. Full Text Search Examples
