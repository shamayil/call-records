<?php

namespace App\Jobs;

use App\Models\CallRecord;
use Carbon\Carbon;
use Exception;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class StoreAndDeleteCallRecordsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $accessToken;
    protected $callRecords;

    public function __construct($accessToken, $callRecords)
    {
        $this->accessToken = $accessToken;
        $this->callRecords = $callRecords;
    }

    public function handle()
    {
        $accessToken = $this->accessToken;
        foreach ($this->callRecords as $callRecord) {
            $callRecordingId = $callRecord['id'];
            $date = Carbon::parse($callRecord['start'])->timezone('Europe/London')->format('Y/m/d');

            $data = $this->callRecordTableData($callRecord, $date);
            $filePath = 'call-recordings/' . $date . '/' . $data['recording_file_name'];

            //download mp3 file and upload to s3
            if (Storage::disk('s3')->exists($filePath)) {
                $this->deleteCallRecordOnVonage($accessToken, $callRecordingId);
                continue;
            }
            $downloadAndUploadToS3 = $this->downloadAndUploadToS3($accessToken, $filePath, $callRecordingId);

            if ($downloadAndUploadToS3 instanceof Exception) {
                Log::error($downloadAndUploadToS3->getMessage());
                continue;
            }

            CallRecord::create($data);

            $this->deleteCallRecordOnVonage($accessToken, $callRecordingId);
        }
    }

    private function callRecordTableData($callRecord, $startDate): array
    {
        $time = Carbon::parse($callRecord['start'])->timezone('Europe/London')->format('g:i A');

        $callDirection = $callRecord['call_direction'];

        $callingPartyName = $callRecord['caller_id'];
        $callingPartyNumber = $this->modifyCallNumber($callRecord['dnis']);
        $calledPartyNumber = $this->modifyCallNumber($callRecord['caller_id']);
        $callPathDetails = "from [$calledPartyNumber] to [$callingPartyNumber]";
        $recordingFileName = $callRecord['dnis'] . '_' . $callingPartyName;

        if ($callDirection == 'OUTBOUND') {
            $callingPartyName = $callRecord['cnam'];
            $callingPartyNumber = $callRecord['caller_id'];
            $calledPartyNumber = $this->modifyCallNumber($callRecord['dnis']);
            $callPathDetails = "from [$callingPartyNumber] to [$calledPartyNumber]";
            $recordingFileName = $callRecord['dnis'] . '_' . $callRecord['caller_id'];
        }

        $recordingFileName = str_replace('/', '_', $startDate) . '_' . str_replace(' ', '_', str_replace(':', '_', $time)) . '_' . $recordingFileName;

        return [
            'recording_file_name' => $recordingFileName . '.mp3',
            'calling_party_number' => $callingPartyNumber,
            'calling_party_name' => $callingPartyName,
            'call_direction' => $callDirection,
            'length' => gmdate('H:i:s', $callRecord['duration'] / 1000),
            'called_party_number' => $calledPartyNumber,
            'date' => $startDate,
            'time' => $time,
            'call_path_details' => $callPathDetails,
            'has_physical_file' => $callRecord['file_name'] ? 1 : 0
        ];
    }

    private function modifyCallNumber($callNumber): string
    {
        if (str_starts_with($callNumber, "+44")) {
            return '0' . substr($callNumber, 3);
        }
        return '0' . substr($callNumber, 2);
    }

    private function deleteCallRecordOnVonage($accessToken, $recording_id): void
    {
        try {
            $baseUrl = config('vonage.call_recording_base_url');
            $response = Http::withToken($accessToken)
                ->withHeaders([
                    'Accept' => 'application/json'
                ])
                ->delete($baseUrl . "v1/api/accounts/self/company_call_recordings/$recording_id");

            if ($response->status() != 204) {
                Log::error('file did not deleted on vonage. id=' . $recording_id);
            }
        } catch (Exception $e) {
            Log::error('deleteCallRecordOnVonage ' . $e->getMessage());
        }
    }

    private function downloadAndUploadToS3($accessToken, $filePath, $callRecordId): ?Exception
    {
        try {
            $baseUrl = config('vonage.call_recording_base_url');
            $response = Http::withToken($accessToken)
                ->withHeaders([
                    'Accept' => 'audio/mpeg'
                ])
                ->get($baseUrl . "v1/api/audio/recording/$callRecordId");
            if ($response->status() !== 200) {
                return new Exception("Error while downloading file with status code " . $response->status(), $response->status());
            }

            Storage::disk('s3')->put($filePath, $response->getBody());
            return null;
        } catch (Exception $e) {
            return new Exception("File downloading and upload to s3" . $e->getMessage(), 500);
        }
    }
}
