<?php

namespace App\Console\Commands;

use App\Jobs\ProcessCallRecordsJob;
use Illuminate\Console\Command;

class ProcessCallRecordsCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'process:call:records';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Fetch all records and store it to bitbucket';

    /**
     * Create a new command instance.
     *
     * @return void
     */
    public function __construct()
    {
        parent::__construct();
    }

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        ProcessCallRecordsJob::dispatch();
    }
}
