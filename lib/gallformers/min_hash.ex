defmodule Gallformers.MinHash do
  @moduledoc """
  Deterministic MinHash implementation for fuzzy duplicate detection.
  """

  use Boundary, deps: [], exports: :all

  @signature_size 128
  @shingle_size 5
  @large_prime 2_147_483_629

  @hash_params Enum.map(0..(@signature_size - 1), fn index ->
                 {
                   1_000_003 + index * 7_919,
                   2_000_033 + index * 15_485
                 }
               end)

  @doc """
  Computes a 128-element MinHash signature for the provided text.
  """
  @spec compute_signature(String.t()) :: [non_neg_integer()]
  def compute_signature(text) when is_binary(text) do
    text
    |> normalize_tokens()
    |> shingles()
    |> signature_for_shingles()
  end

  @doc """
  Computes similarity between two MinHash signatures.
  """
  @spec similarity([integer()], [integer()]) :: float()
  def similarity(left, right) when is_list(left) and is_list(right) do
    shared_length = min(length(left), length(right))

    if shared_length == 0 do
      0.0
    else
      left
      |> Enum.zip(right)
      |> Enum.count(fn {a, b} -> a == b end)
      |> Kernel./(shared_length)
    end
  end

  defp normalize_tokens(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s]/u, " ")
    |> String.split(~r/\s+/u, trim: true)
  end

  defp shingles([]), do: []

  defp shingles(tokens) when length(tokens) < @shingle_size, do: [Enum.join(tokens, " ")]

  defp shingles(tokens) do
    tokens
    |> Enum.chunk_every(@shingle_size, 1, :discard)
    |> Enum.map(&Enum.join(&1, " "))
  end

  defp signature_for_shingles([]), do: List.duplicate(0, @signature_size)

  defp signature_for_shingles(shingles) do
    shingle_hashes = Enum.map(shingles, &base_hash/1)

    Enum.map(@hash_params, fn {a, b} ->
      Enum.reduce(shingle_hashes, @large_prime, fn shingle_hash, acc ->
        min(acc, rem(a * shingle_hash + b, @large_prime))
      end)
    end)
  end

  defp base_hash(shingle) do
    <<value::unsigned-big-integer-size(64), _rest::binary>> = :crypto.hash(:sha256, shingle)
    rem(value, @large_prime)
  end
end
