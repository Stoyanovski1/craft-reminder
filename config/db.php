<?php
/**
 * Database Configuration
 *
 * All of your system's database configuration settings go in this file.
 */

use craft\helpers\App;

return [
    'driver' => App::env('DB_DRIVER'),
    'server' => App::env('DB_SERVER'),
    'port' => App::env('DB_PORT'),
    'database' => App::env('DB_DATABASE'),
    'user' => App::env('DB_USER'),
    'password' => App::env('DB_PASSWORD'),
    'charset' => 'utf8',
];