<?php

return [
    'paths' => ['api/*', 'graphql', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => [
        'http://localhost:8100',
        'http://127.0.0.1:8100',
        'http://localhost:4200',
        'http://127.0.0.1:4200',
    ],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,
];
