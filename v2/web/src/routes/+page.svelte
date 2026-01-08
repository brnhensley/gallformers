<script>
	import '../app.css';
</script>

<main>
	<div class="container">
		<h1>Gallformers</h1>
		<p class="tagline">A comprehensive database of plant galls and their causative organisms</p>
		<div class="coming-soon">
			<p>Version 2 - Coming Soon</p>
		</div>
	</div>
</main>

<style>
	main {
		display: flex;
		justify-content: center;
		align-items: center;
		min-height: 100vh;
		padding: 2rem;
	}

	.container {
		text-align: center;
		max-width: 600px;
	}

	h1 {
		font-size: 3rem;
		color: var(--color-primary);
		margin-bottom: 0.5rem;
	}

	.tagline {
		font-size: 1.25rem;
		color: var(--color-text-muted);
		margin-bottom: 3rem;
	}

	.coming-soon {
		background: linear-gradient(135deg, var(--color-primary), var(--color-primary-light));
		color: white;
		padding: 1.5rem 3rem;
		border-radius: 8px;
		font-size: 1.5rem;
		font-weight: 500;
	}

	.coming-soon p {
		margin: 0;
	}
</style>
