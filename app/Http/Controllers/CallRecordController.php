<?php

namespace App\Http\Controllers;

use App\Models\CallRecord;
use Illuminate\Support\Facades\Storage;
use Throwable;

class CallRecordController extends Controller
{
    public function __invoke($file_name)
    {
        $callRecord = CallRecord::select('recording_file_name')
            ->where('recording_file_name', $file_name)
            ->first();

        if (!$callRecord ){
            return [
                'data' => [],
                'status' => 'ERROR',
                'message' => "File Not Found",
                'errors' => null,
            ];
        }

        $pathValues = explode('_', $callRecord->recording_file_name);
        $sourceLocation = "call-recordings/$pathValues[0]/$pathValues[1]/$pathValues[2]/$callRecord->recording_file_name";

        try {
            $tempUrl = Storage::disk('s3')->temporaryUrl($sourceLocation, now()->addMinutes(5));
            return [
                'data' => $tempUrl,
                'status' => 'OK',
                'message' => "Link Generated Successfully",
                'errors' => null,
            ];
        } catch (Throwable $exception) {
            return [
                'data' => [],
                'status' => 'ERROR',
                'message' => $exception->getMessage(),
                'errors' => null,
            ];
        }
    }
}
