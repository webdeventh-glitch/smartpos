<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Smart POS - Laravel REST API Sync Controller
 * 
 * Routes to add in routes/api.php:
 * Route::get('/health', [SyncController::class, 'health']);
 * Route::post('/sync/push', [SyncController::class, 'push']);
 * Route::get('/sync/pull', [SyncController::class, 'pull']);
 */
class SyncController extends Controller
{
    /**
     * Health check endpoint called by Smart POS app to test connection
     * GET /api/health
     */
    public function health()
    {
        try {
            DB::connection()->getPdo();
            return response()->json([
                'status' => 'ok',
                'service' => 'Smart POS Cloud Sync API',
                'database' => 'MySQL Connected',
                'server_time' => now()->toIso8601String(),
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Database connection failed: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Receive offline batch changes pushed from Flutter app
     * POST /api/sync/push
     */
    public function push(Request $request)
    {
        $branchId = $request->input('branch_id', 1);
        $batch = $request->input('batch', []);

        if (empty($batch)) {
            return response()->json(['status' => 'success', 'pushed' => 0, 'message' => 'Batch is empty'], 200);
        }

        $processedCount = 0;
        $errors = [];

        DB::beginTransaction();
        try {
            foreach ($batch as $item) {
                $type = $item['entity_type'] ?? '';
                $action = $item['action'] ?? 'create';
                $payload = $item['payload'] ?? [];

                switch ($type) {
                    case 'product':
                        $this->syncProduct($branchId, $action, $payload);
                        break;
                    case 'sale':
                        $this->syncSale($branchId, $action, $payload);
                        break;
                    case 'contact':
                    case 'customer':
                    case 'supplier':
                        $this->syncContact($branchId, $action, $payload);
                        break;
                }

                // Log sync audit
                DB::table('sync_logs')->insert([
                    'branch_id' => $branchId,
                    'direction' => 'push',
                    'entity_type' => $type,
                    'entity_id' => $item['entity_id'] ?? 'N/A',
                    'action' => $action,
                    'status' => 'success',
                    'payload' => json_encode($payload),
                    'created_at' => now(),
                ]);

                $processedCount++;
            }

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => "Successfully processed $processedCount changes in MySQL.",
                'processed' => $processedCount,
            ], 200);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Smart POS Sync Push Error: ' . $e->getMessage());

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to process sync batch: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Send remote changes down to Flutter desktop app
     * GET /api/sync/pull?since=YYYY-MM-DDTHH:mm:ss&branch_id=1
     */
    public function pull(Request $request)
    {
        $since = $request->query('since');
        $branchId = $request->query('branch_id', 1);

        $queryProducts = DB::table('products')->where('branch_id', $branchId);
        $queryCustomers = DB::table('contacts')->where('type', 'customer');

        if (!empty($since)) {
            $queryProducts->where('updated_at', '>=', $since);
            $queryCustomers->where('updated_at', '>=', $since);
        }

        $products = $queryProducts->limit(200)->get();
        $customers = $queryCustomers->limit(200)->get();

        return response()->json([
            'status' => 'success',
            'timestamp' => now()->toIso8601String(),
            'data' => [
                'products' => $products,
                'customers' => $customers,
            ]
        ], 200);
    }

    // ==================== HELPER SYNC METHODS ====================

    private function syncProduct($branchId, $action, array $data)
    {
        $sku = $data['sku'] ?? null;
        if (!$sku) return;

        DB::table('products')->updateOrInsert(
            ['sku' => $sku],
            [
                'branch_id' => $branchId,
                'name' => $data['name'] ?? 'Product',
                'barcode' => $data['barcode'] ?? $sku,
                'category_name' => $data['category_name'] ?? null,
                'brand_name' => $data['brand_name'] ?? null,
                'unit' => $data['unit'] ?? 'Pc',
                'purchase_price' => $data['purchase_price'] ?? 0,
                'selling_price' => $data['selling_price'] ?? 0,
                'stock_quantity' => $data['stock_quantity'] ?? 0,
                'batch_number' => $data['batch_number'] ?? '',
                'expiry_date' => $data['expiry_date'] ?? '',
                'updated_at' => now(),
            ]
        );
    }

    private function syncSale($branchId, $action, array $data)
    {
        $inv = $data['invoice_no'] ?? null;
        if (!$inv) return;

        $saleId = DB::table('sales')->updateOrInsert(
            ['invoice_no' => $inv],
            [
                'branch_id' => $branchId,
                'customer_id' => $data['customer_id'] ?? null,
                'customer_name' => $data['customer_name'] ?? 'Walk-in Customer',
                'subtotal' => $data['subtotal'] ?? 0,
                'discount' => $data['discount'] ?? 0,
                'tax_amount' => $data['tax_amount'] ?? 0,
                'total_amount' => $data['total_amount'] ?? 0,
                'paid_amount' => $data['paid_amount'] ?? 0,
                'payment_method' => $data['payment_method'] ?? 'cash',
                'payment_status' => $data['payment_status'] ?? 'paid',
                'sale_status' => $data['sale_status'] ?? 'final',
                'note' => $data['note'] ?? null,
                'created_at' => $data['created_at'] ?? now(),
                'updated_at' => now(),
            ]
        );

        // Insert items if provided
        if (isset($data['items']) && is_array($data['items'])) {
            $parentSale = DB::table('sales')->where('invoice_no', $inv)->first();
            if ($parentSale) {
                DB::table('sale_items')->where('sale_id', $parentSale->id)->delete();
                foreach ($data['items'] as $item) {
                    DB::table('sale_items')->insert([
                        'sale_id' => $parentSale->id,
                        'product_id' => $item['product_id'] ?? null,
                        'product_name' => $item['product_name'] ?? 'Item',
                        'sku' => $item['sku'] ?? null,
                        'quantity' => $item['quantity'] ?? 1,
                        'unit_price' => $item['unit_price'] ?? 0,
                        'subtotal' => $item['subtotal'] ?? 0,
                        'created_at' => now(),
                    ]);
                }
            }
        }
    }

    private function syncContact($branchId, $action, array $data)
    {
        $name = $data['name'] ?? null;
        $phone = $data['phone'] ?? null;
        if (!$name) return;

        DB::table('contacts')->updateOrInsert(
            ['phone' => $phone, 'name' => $name],
            [
                'type' => $data['type'] ?? 'customer',
                'business_name' => $data['business_name'] ?? null,
                'email' => $data['email'] ?? null,
                'address' => $data['address'] ?? null,
                'balance' => $data['balance'] ?? 0,
                'updated_at' => now(),
            ]
        );
    }
}
