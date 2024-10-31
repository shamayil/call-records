<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/health', function () {
    return response()->json(['message' => 'health check - 200'], 200);
});

Route::get('/', function () {
    return response()->json(['message' => 'health check - 200'], 200);
});
