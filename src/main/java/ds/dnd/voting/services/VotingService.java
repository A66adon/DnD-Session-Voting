package ds.dnd.voting.services;

import ds.dnd.voting.dto.TimeSlotStatsDTO;
import ds.dnd.voting.dto.VoteResultDTO;
import ds.dnd.voting.dto.WeekResultDTO;
import ds.dnd.voting.model.TimeSlot;
import ds.dnd.voting.model.Vote;
import ds.dnd.voting.model.VotingWeek;
import ds.dnd.voting.repositories.TimeSlotRepository;
import ds.dnd.voting.repositories.VoteRepository;
import ds.dnd.voting.repositories.VotingWeekRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class VotingService {

    private final VotingWeekRepository votingWeekRepository;
    private final TimeSlotRepository timeSlotRepository;
    private final VoteRepository voteRepository;

    /**
     * Get the current active voting week
     */
    public VotingWeek getCurrentWeek() {
        return votingWeekRepository.findByActiveTrue()
                .orElseGet(this::createNewWeek);
    }

    /**
     * Get detailed results for a specific week including who voted for what
     * Returns null if the week doesn't exist (no error thrown)
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getWeekResults(Long weekId) {
        Optional<VotingWeek> weekOpt = votingWeekRepository.findById(weekId);
        if (weekOpt.isEmpty()) {
            return null; // Week doesn't exist, return null instead of throwing exception
        }
        return buildWeekResultDTO(weekOpt.get());
    }

    /**
     * Get results for the current active week
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getCurrentWeekResults() {
        VotingWeek currentWeek = getCurrentWeek();
        return buildWeekResultDTO(currentWeek);
    }

    /**
     * Build a WeekResultDTO from a VotingWeek
     * Contains vote results, timeslot statistics, and winner determination
     */
    private WeekResultDTO buildWeekResultDTO(VotingWeek week) {
        List<Vote> votes = voteRepository.findVotesByVotingWeek(week.getId());

        // Create vote results showing who voted for what
        List<VoteResultDTO> voteResults = votes.stream()
                .map(vote -> new VoteResultDTO(
                        vote.getVoterName(),
                        vote.getTimeslots().stream()
                                .map(TimeSlot::getDatetime)
                                .sorted()
                                .collect(Collectors.toList()),
                        vote.getPreferredTimeSlots() != null ?
                                vote.getPreferredTimeSlots().stream()
                                        .map(TimeSlot::getDatetime)
                                        .sorted()
                                        .collect(Collectors.toList()) :
                                new ArrayList<>()
                ))
                .toList();

        // Calculate statistics for each timeslot
        List<TimeSlotStatsDTO> timeSlotStats = week.getTimeSlots().stream()
                .map(timeSlot -> {
                    int voteCount = timeSlotRepository
                            .countVotesByTimeSlotId(timeSlot.getId())
                            .intValue();

                    int preferredCount = timeSlotRepository
                            .countPreferredVotesByTimeSlotId(timeSlot.getId())
                            .intValue();

                    return new TimeSlotStatsDTO(
                            timeSlot.getId(),
                            timeSlot.getDatetime(),
                            voteCount,
                            preferredCount,
                            false
                    );
                })
                .sorted(Comparator.comparing(TimeSlotStatsDTO::getDatetime))
                .toList();

        // Determine winners based on weighted vote count (all timeslots with max votes win)
        int maxVotes = timeSlotStats.stream()
                .mapToInt(TimeSlotStatsDTO::getVoteCount)
                .max()
                .orElse(0);

        List<TimeSlotStatsDTO> topByVotes = timeSlotStats.stream()
                .filter(ts -> ts.getVoteCount() == maxVotes && maxVotes > 0)
                .collect(Collectors.toList());

        List<TimeSlotStatsDTO> winners;

        if (topByVotes.size() == 1) {
            winners = topByVotes;
        } else {
            // 3️⃣ Tie-Breaker: Preferred Votes
            int maxPreferred = topByVotes.stream()
                    .mapToInt(TimeSlotStatsDTO::getPreferredVoteCount)
                    .max()
                    .orElse(0);

            winners = topByVotes.stream()
                    .filter(ts -> ts.getPreferredVoteCount() == maxPreferred)
                    .collect(Collectors.toList());
        }

        winners.forEach(ts -> ts.setWinner(true));

        WeekResultDTO result = new WeekResultDTO();
        result.setWeekId(week.getId());
        result.setDeadline(week.getDeadline());
        result.setTimeSlots(timeSlotStats);
        result.setVotes(voteResults);
        result.setWinnerTimeSlots(winners);

        return result;
    }

    /**
     * Get all past weeks with their results
     */
    @Transactional(readOnly = true)
    public List<WeekResultDTO> getAllPastWeeks() {
        List<VotingWeek> allWeeks = votingWeekRepository.findAllByOrderByDeadlineDesc();

        return allWeeks.stream()
                .filter(week -> week.getDeadline().isBefore(LocalDate.now()))
                .map(week -> getWeekResults(week.getId()))
                .filter(Objects::nonNull) // Filter out any null results
                .collect(Collectors.toList());
    }

    /**
     * Get all weeks including current
     */
    @Transactional(readOnly = true)
    public List<WeekResultDTO> getAllWeeks() {
        List<VotingWeek> allWeeks = votingWeekRepository.findAllByOrderByDeadlineDesc();

        return allWeeks.stream()
                .map(week -> getWeekResults(week.getId()))
                .filter(Objects::nonNull) // Filter out any null results
                .collect(Collectors.toList());
    }

    /**
     * Manually trigger a week reset (useful for testing)
     */
    @Transactional
    public VotingWeek resetWeek() {
        log.info("Manually triggering week reset");
        return createNewWeek();
    }
    /**
     * Scheduled task to reset the voting week every Monday at midnight
     */
    @Scheduled(cron = "0 0 0 * * MON", zone = "Europe/Berlin")
    @Transactional
    public void scheduledWeekReset() {
        log.info("Scheduled week reset triggered at {}", LocalDateTime.now());
        createNewWeek();
    }

    /**
     * Create a new voting week with fresh timeslots
     */
    @Transactional
    protected VotingWeek createNewWeek() {
        LocalDate today = LocalDate.now();

        // Deactivate existing active weeks
        votingWeekRepository.deactivateAll();

        // Calculate deadline: next Sunday
        LocalDate nextSunday = today.with(TemporalAdjusters.next(DayOfWeek.SUNDAY));

        // Create new voting week
        VotingWeek newWeek = new VotingWeek();
        newWeek.setDeadline(nextSunday);
        newWeek.setActive(true);
        newWeek.setTimeSlots(new ArrayList<>());

        VotingWeek savedWeek = votingWeekRepository.save(newWeek);

        // Generate timeslots for the upcoming week (Monday to Sunday after deadline)
        List<TimeSlot> timeSlots = generateTimeSlots(nextSunday, savedWeek);
        timeSlotRepository.saveAll(timeSlots);

        savedWeek.getTimeSlots().addAll(timeSlots);

        log.info("Created new voting week with ID {} and deadline {}", savedWeek.getId(), nextSunday);

        return savedWeek;
    }

    /**
     * Generate timeslots for the week following the deadline
     * Creates slots for each day of the week at common gaming times
     */
    private List<TimeSlot> generateTimeSlots(LocalDate deadline, VotingWeek votingWeek) {
        List<TimeSlot> timeSlots = new ArrayList<>();

        // Start from Monday after the deadline
        LocalDate startDate = deadline.plusDays(1); // Monday after Sunday deadline

        // Generate slots for 7 days (Monday to Sunday)
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
            LocalDate date = startDate.plusDays(dayOffset);
            DayOfWeek dayOfWeek = date.getDayOfWeek();

            // All days get 18:00 slot
            timeSlots.add(new TimeSlot(LocalDateTime.of(date, LocalTime.of(18, 0)), votingWeek));

            // Saturday and Sunday also get 10:00 slot
            if (dayOfWeek == DayOfWeek.SATURDAY || dayOfWeek == DayOfWeek.SUNDAY) {
                timeSlots.add(new TimeSlot(LocalDateTime.of(date, LocalTime.of(10, 0)), votingWeek));
            }
        }

        log.info("Generated {} timeslots for week starting {}", timeSlots.size(), startDate);

        return timeSlots;
    }

    /**
     * Submit a vote for the current week
     * If the user has already voted, the existing vote will be updated
     */
    @Transactional
    public Vote submitVote(String voterName, List<Long> timeSlotIds, List<Long> preferredTimeSlotIds) {
        VotingWeek currentWeek = getCurrentWeek();

        // Verify all timeslots belong to current week
        List<TimeSlot> timeSlots = timeSlotRepository.findAllById(timeSlotIds);

        boolean allBelongToCurrentWeek = timeSlots.stream()
                .allMatch(ts -> ts.getVotingWeek().getId().equals(currentWeek.getId()));

        if (!allBelongToCurrentWeek) {
            throw new RuntimeException("Some timeslots do not belong to the current voting week");
        }

        // Handle preferred timeslots
        List<TimeSlot> preferredTimeSlots = new ArrayList<>();
        if (preferredTimeSlotIds != null && !preferredTimeSlotIds.isEmpty()) {
            // Verify all preferred timeslots are part of the selected timeslots
            if (!timeSlotIds.containsAll(preferredTimeSlotIds)) {
                throw new RuntimeException("All preferred timeslots must be among the selected timeslots");
            }
            preferredTimeSlots = timeSlotRepository.findAllById(preferredTimeSlotIds);

            if (preferredTimeSlots.size() != preferredTimeSlotIds.size()) {
                throw new RuntimeException("Some preferred timeslots not found");
            }
        }

        // Check if user has already voted for this week
        Optional<Vote> existingVote = voteRepository.findByVoterNameAndVotingWeek(voterName, currentWeek.getId());

        Vote vote;
        if (existingVote.isPresent()) {
            // Update existing vote
            vote = existingVote.get();
            vote.getTimeslots().clear();
            vote.getTimeslots().addAll(timeSlots);
            if (vote.getPreferredTimeSlots() == null) {
                vote.setPreferredTimeSlots(new ArrayList<>());
            }
            vote.getPreferredTimeSlots().clear();
            vote.getPreferredTimeSlots().addAll(preferredTimeSlots);
            log.info("Updated vote for {} with {} timeslots, preferred: {}", voterName, timeSlotIds.size(), preferredTimeSlotIds != null ? preferredTimeSlotIds.size() : 0);
        } else {
            // Create new vote
            vote = new Vote(voterName, timeSlots, preferredTimeSlots);
            log.info("Created new vote for {} with {} timeslots, preferred: {}", voterName, timeSlotIds.size(), preferredTimeSlotIds != null ? preferredTimeSlotIds.size() : 0);
        }

        return voteRepository.save(vote);
    }

}
