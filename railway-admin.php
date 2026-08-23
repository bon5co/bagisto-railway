<?php
/**
 * Seeds or re-applies the Bagisto administrator from the deployment's own
 * credentials.
 *
 * Runs on every boot, so redeploying the service is a working password reset.
 * Bagisto ships no non-interactive way to change an administrator password and
 * its own reset path is an emailed link, which a fresh deploy has no SMTP for.
 */
$email    = getenv('BAGISTO_ADMIN_EMAIL');
$password = getenv('BAGISTO_ADMIN_PASSWORD');

if ($email === false || trim($email) === '' || $password === false || $password === '') {
    fwrite(STDERR, "[railway] BAGISTO_ADMIN_EMAIL and BAGISTO_ADMIN_PASSWORD are required.\n");
    exit(1);
}

$dsn = sprintf(
    'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
    getenv('DB_HOST') ?: '127.0.0.1',
    getenv('DB_PORT') ?: '3306',
    getenv('DB_DATABASE') ?: 'bagisto'
);

$pdo = new PDO($dsn, getenv('DB_USERNAME') ?: 'bagisto', getenv('DB_PASSWORD') ?: '', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);

// Laravel's bcrypt driver, same cost as config/hashing.php.
$hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
$now  = date('Y-m-d H:i:s');

$existing = $pdo->query('SELECT id FROM admins ORDER BY id ASC LIMIT 1')->fetch(PDO::FETCH_ASSOC);

if ($existing) {
    $stmt = $pdo->prepare(
        'UPDATE admins SET email = ?, password = ?, status = 1, role_id = 1, updated_at = ? WHERE id = ?'
    );
    $stmt->execute([$email, $hash, $now, $existing['id']]);
    fwrite(STDOUT, "[railway] administrator {$email} updated (password re-applied).\n");
} else {
    $stmt = $pdo->prepare(
        'INSERT INTO admins (name, email, password, api_token, status, role_id, created_at, updated_at)'
        . ' VALUES (?, ?, ?, ?, 1, 1, ?, ?)'
    );
    $stmt->execute(['Admin', $email, $hash, bin2hex(random_bytes(40)), $now, $now]);
    fwrite(STDOUT, "[railway] administrator {$email} created.\n");
}

// Any other administrator row can only be upstream's admin@example.com demo
// account, whose password (admin123) is published in the Bagisto source.
$removed = $pdo->prepare('DELETE FROM admins WHERE email <> ?');
$removed->execute([$email]);
if ($removed->rowCount() > 0) {
    fwrite(STDOUT, "[railway] removed {$removed->rowCount()} default administrator row(s).\n");
}
