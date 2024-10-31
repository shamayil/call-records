<?php

namespace App\Jobs;

use App\Models\CallRecordSchedule;
use Carbon\Carbon;
use Exception;
use GuzzleHttp\Client;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ProcessCallRecordsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle()
    {
        $callRecordSchedule = CallRecordSchedule::create([
            'date' => Carbon::today()->format('Y-m-d'),
            'start_at' => Carbon::now(),
            'is_automated' => 1,
            'status' => 'Initiated',
        ]);
        $callRecordScheduleId = $callRecordSchedule->id;

        $accessToken = $this->authentication();
        if (!$accessToken) {
            Log::error('Access token not found');
            return;
        }

        $perPage = config('vonage.fetch_data_per_page');
        $this->storeCallRecords($accessToken, $callRecordScheduleId, $perPage);
    }

    private function authentication(): ?string
    {
        $client = new Client();

        try {
            $username = config('vonage.username');
            $password = config('vonage.password');
            $clientId = config('vonage.client_id');
            $clientSecret = config('vonage.client_secret');

            $response = $client->post('https://api.vonage.com/token', [
                'form_params' => [
                    'username' => $username,
                    'password' => $password,
                    'client_id' => $clientId,
                    'client_secret' => $clientSecret,
                    'grant_type' => 'password',
                    'scope' => 'openid',
                ],
                'headers' => [
                    'Content-Type' => 'application/x-www-form-urlencoded'
                ]
            ]);

            $body = $response->getBody();
            $contents = $body->getContents();
            $data = json_decode($contents, true);
            return $data['access_token'];

        } catch (Exception $e) {
            Log::error("Authentication - " . $e->getMessage());
            return null;
        }
    }

    private function storeCallRecords($accessToken, $callRecordScheduleId, $perPage = 150): void
    {
        CallRecordSchedule::find($callRecordScheduleId)->update(['status' => 'Processing']);

        $contents = $this->getCompanyCallRecordings($accessToken, $perPage);

        if (!isset($contents['_embedded']) && !isset($contents['_embedded']['recordings']) && count($contents['_embedded']['recordings']) == 0) {
            Log::info('There have no call records');
            return;
        }

        $data = $contents['_embedded']['recordings'];
        $callRecordChunks = array_chunk($data, 10);

        $jobs = [];
        foreach ($callRecordChunks as $callRecords) {
            $jobs[] = new StoreAndDeleteCallRecordsJob($accessToken, $callRecords);
        }

        if (count($jobs) > 0) {
            $jobs[] = function () use ($callRecordScheduleId) {
                CallRecordSchedule::find($callRecordScheduleId)->update([
                    'status' => 'Success',
                    'end_at' => Carbon::now()
                ]);
            };

            Bus::chain($jobs)->dispatch();
        }
    }

    private function getCompanyCallRecordings($accessToken, $perPage = 150): ?array
    {
        try {
            $accountId = "self";
            $queryParams = "page_size=$perPage&order=start:ASC";
            $baseUrl = config('vonage.call_recording_base_url');
            $response = Http::withToken($accessToken)
                ->get($baseUrl . "api/accounts/$accountId/company_call_recordings?$queryParams");

            $body = $response->getBody();
            return json_decode($body->getContents(), true);

        } catch (Exception $e) {
            Log::error("getCompanyCallRecording - " . $e->getMessage());
            return null;
        }
    }
}
