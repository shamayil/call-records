<?php

return [
    'username' => env('VONAGE_USERNAME'),
    'password' => env('VONAGE_PASSWORD'),
    'client_id' => env('VONAGE_CLIENT_ID'),
    'client_secret' => env('VONAGE_CLIENT_SECRET'),
    'call_recording_base_url' => env('VONAGE_CALL_RECORDING_BASE_URL','https://api.vonage.com/t/vbc.prod/call_recording/'),
    'fetch_data_per_page' => env('VONAGE_FETCH_PER_PAGE', 150) //max:150
];
